import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateAttendanceDto,
  CreateBatchAttendanceDto,
  UpdateAttendanceDto,
} from './dto/attendance.dto';
import { AttendanceStatus, Prisma } from '@prisma/client';
import { NotificationsService } from '../notifications/notifications.service';
import { desiredCharges, HalaqaFineRates } from './fine-reconciliation';

/// Who is recording the attendance. Carries the teacher id because the halaqa
/// a student sits in is what decides whether a given teacher may write for him.
/// Mirrors FineActor, so the two paths that move a student's money agree on
/// what an actor is.
export type AttendanceActor = {
  id: number;
  role: string;
  teacher?: { id: number } | null;
};

@Injectable()
export class AttendanceService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  // A student who was absent cannot have recited that day. Attendance is the
  // authority when the two disagree — the teacher is correcting the record —
  // so memorization already logged for that date is removed with the same
  // write. Doing it in the caller's transaction keeps the pair consistent: the
  // deletion cannot land without the ABSENT row it follows from.
  private async clearMemorizationIfAbsent(
    tx: Prisma.TransactionClient,
    studentId: number,
    date: Date,
    status: AttendanceStatus,
  ) {
    // LATE still means the student turned up, so only ABSENT discards work.
    if (status !== AttendanceStatus.ABSENT) return;
    await tx.memorizationProgress.deleteMany({ where: { studentId, date } });
  }

  // Brings a day's auto-charges in line with the attendance row just written,
  // in the same transaction that wrote it — so a fine cannot outlive the row
  // it follows from. Returns what was charged, for the notification body.
  //
  // Written as a reconciliation rather than an increment because attendance is
  // an upsert: the teacher re-saves the same day freely, and adding on each
  // save would charge for one absence many times over.
  private async reconcileFines(
    tx: Prisma.TransactionClient,
    studentId: number,
    date: Date,
    status: AttendanceStatus,
    missedMemorization: boolean,
    actorUserId: number | null,
  ): Promise<number> {
    const student = await tx.student.findUnique({
      where: { id: studentId },
      select: {
        userId: true,
        user: { select: { role: true } },
        halaqa: {
          select: {
            isAdult: true,
            absenceFee: true,
            lateFee: true,
            missedMemorizationFee: true,
          },
        },
      },
    });

    if (student?.user.role !== 'ADULT_STUDENT') return 0;

    const halaqa = student.halaqa;
    const rates: HalaqaFineRates | null =
      halaqa && halaqa.isAdult
        ? {
            absenceFee: halaqa.absenceFee,
            lateFee: halaqa.lateFee,
            missedMemorizationFee: halaqa.missedMemorizationFee,
          }
        : null;

    const wanted = desiredCharges({ status, missedMemorization, rates });

    const existing = await tx.fineEntry.findMany({
      where: { studentId, date, source: { not: 'MANUAL' } },
      select: { id: true, source: true },
    });

    const wantedSources = new Set<string>(wanted.map((c) => c.source));
    const stale = existing
      .filter((row) => !wantedSources.has(row.source))
      .map((row) => row.id);
    if (stale.length > 0) {
      await tx.fineEntry.deleteMany({ where: { id: { in: stale } } });
    }

    const kept = new Set(
      existing.filter((row) => wantedSources.has(row.source)).map((r) => r.source),
    );

    let charged = 0;
    for (const charge of wanted) {
      // An existing charge keeps the amount it was created at. Raising a
      // halaqa's rate must not reprice a day that was already charged, and
      // re-saving an old sheet is exactly how that would happen.
      if (kept.has(charge.source)) continue;
      await tx.fineEntry.create({
        data: {
          studentId,
          kind: 'CHARGE',
          amount: charge.amount,
          source: charge.source,
          date,
          createdById: actorUserId ?? student.userId,
        },
      });
      charged += charge.amount;
    }

    return charged;
  }

  /// What a single write changed, so the notifier can tell a real transition
  /// from a re-save. `previous` is null when the row is new, which counts as
  /// a change: the first time a student is marked absent is exactly when the
  /// guardian should hear about it. `charged` is whatever reconcileFines
  /// billed for that same write, carried along so the notification can say so.
  private async notifyGuardians(
    transitions: Array<{
      studentId: number;
      status: AttendanceStatus;
      previous: AttendanceStatus | null;
      charged?: number;
    }>,
  ) {
    // Runs after the transaction commits, so a write that rolled back never
    // notifies. Failures are swallowed: a notification that does not send must
    // not cost the attendance record that prompted it.
    try {
      for (const t of transitions) {
        const announces =
          t.status === AttendanceStatus.ABSENT ||
          t.status === AttendanceStatus.LATE;
        if (!announces || t.status === t.previous) continue;

        const student = await this.prisma.student.findUnique({
          where: { id: t.studentId },
          select: {
            userId: true,
            user: { select: { fullName: true, role: true } },
            parent: { select: { userId: true } },
          },
        });

        // Whoever should hear about this student: the parent for a child, and
        // the adult student himself, who has no parent row by construction.
        const recipientId =
          student?.parent?.userId ??
          (student?.user.role === 'ADULT_STUDENT' ? student.userId : null);
        if (!recipientId) continue;

        const name = student?.user?.fullName ?? '';
        const isSelf = student?.user.role === 'ADULT_STUDENT';
        // Being marked absent and being charged for it are one piece of news,
        // so the amount rides with the notification rather than arriving
        // separately.
        const fee = t.charged && t.charged > 0 ? ` — رسوم ${t.charged} دج` : '';

        await this.notifications.create(
          t.status === AttendanceStatus.ABSENT
            ? {
                userId: recipientId,
                studentId: t.studentId,
                title: 'غياب',
                body: isSelf
                  ? `تم تسجيل غيابك اليوم${fee}`
                  : `تم تسجيل غياب ${name} اليوم`,
              }
            : {
                userId: recipientId,
                studentId: t.studentId,
                title: 'تأخر',
                body: isSelf
                  ? `تم تسجيل تأخرك اليوم${fee}`
                  : `تم تسجيل تأخر ${name} اليوم`,
              },
        );
      }
    } catch (_) {
      // Deliberately silent — see above.
    }
  }

  /// Refuses a teacher writing attendance for a student who is not hers.
  ///
  /// Recording attendance now moves money — an ABSENT mark on an adult student
  /// creates a fine — so this path needs the same ownership rule the manual
  /// fines path already enforces. Without it a teacher could cost another
  /// teacher's student money and then be unable to reduce it, since the fines
  /// service would refuse her the correction.
  ///
  /// Reads are deliberately looser and stay that way; ADMIN and MANAGER are
  /// unrestricted because oversight is their job. A null actor is not a
  /// teacher and so passes: the controller is the only production caller and
  /// always supplies one.
  private async assertCanRecord(
    studentIds: number[],
    actor: AttendanceActor | null,
  ) {
    if (actor?.role !== 'TEACHER') return;

    // Each side is checked on its own rather than compared directly: a missing
    // teacher profile and a student with no halaqa would otherwise both read as
    // undefined and cancel out into an accidental pass.
    const teacherId = actor.teacher?.id;
    if (teacherId == null) {
      throw new ForbiddenException('لا يمكنك تسجيل حضور طالب من حلقة أخرى');
    }

    const students = await this.prisma.student.findMany({
      where: { id: { in: studentIds } },
      select: { id: true, halaqa: { select: { teacherId: true } } },
    });

    const allowed = new Set(
      students
        .filter((s) => s.halaqa?.teacherId === teacherId)
        .map((s) => s.id),
    );

    // An id that matched no row fails here too, so a probe cannot tell a
    // student who does not exist from one in someone else's halaqa.
    if (studentIds.some((id) => !allowed.has(id))) {
      throw new ForbiddenException('لا يمكنك تسجيل حضور طالب من حلقة أخرى');
    }
  }

  async create(dto: CreateAttendanceDto, actor: AttendanceActor | null = null) {
    await this.assertCanRecord([dto.studentId], actor);
    const actorUserId = actor?.id ?? null;
    const date = new Date(dto.date);
    const missedMemorization = dto.missedMemorization ?? false;
    const { record, previous, charged } = await this.prisma.$transaction(
      async (tx) => {
        const before = await tx.attendance.findUnique({
          where: { studentId_date: { studentId: dto.studentId, date } },
          select: { status: true },
        });
        const written = await tx.attendance.upsert({
          where: { studentId_date: { studentId: dto.studentId, date } },
          update: { status: dto.status, notes: dto.notes, missedMemorization },
          create: {
            studentId: dto.studentId,
            date,
            status: dto.status,
            notes: dto.notes,
            missedMemorization,
          },
        });
        await this.clearMemorizationIfAbsent(tx, dto.studentId, date, dto.status);
        const charged = await this.reconcileFines(
          tx,
          dto.studentId,
          date,
          dto.status,
          missedMemorization,
          actorUserId,
        );
        return { record: written, previous: before?.status ?? null, charged };
      },
    );

    await this.notifyGuardians([
      { studentId: dto.studentId, status: dto.status, previous, charged },
    ]);
    return record;
  }

  async createBatch(
    dto: CreateBatchAttendanceDto,
    actor: AttendanceActor | null = null,
  ) {
    // Checked for the whole batch before anything is written. Refusing record
    // by record would leave the teacher's sheet half-saved, with her own
    // students recorded and the rest silently dropped.
    await this.assertCanRecord(
      dto.records.map((r) => r.studentId),
      actor,
    );
    const actorUserId = actor?.id ?? null;
    const transitions: Array<{
      studentId: number;
      status: AttendanceStatus;
      previous: AttendanceStatus | null;
      charged?: number;
    }> = [];

    const records = await this.prisma.$transaction(async (tx) => {
      const written: Array<Awaited<ReturnType<typeof tx.attendance.upsert>>> =
        [];
      for (const r of dto.records) {
        const date = new Date(r.date);
        const missedMemorization = r.missedMemorization ?? false;
        const before = await tx.attendance.findUnique({
          where: { studentId_date: { studentId: r.studentId, date } },
          select: { status: true },
        });
        written.push(
          await tx.attendance.upsert({
            where: { studentId_date: { studentId: r.studentId, date } },
            update: { status: r.status, notes: r.notes, missedMemorization },
            create: {
              studentId: r.studentId,
              date,
              status: r.status,
              notes: r.notes,
              missedMemorization,
            },
          }),
        );
        await this.clearMemorizationIfAbsent(tx, r.studentId, date, r.status);
        const charged = await this.reconcileFines(
          tx,
          r.studentId,
          date,
          r.status,
          missedMemorization,
          actorUserId,
        );
        transitions.push({
          studentId: r.studentId,
          status: r.status,
          previous: before?.status ?? null,
          charged,
        });
      }
      return written;
    });

    await this.notifyGuardians(transitions);
    return { count: records.length, records };
  }

  async upsert(
    studentId: number,
    date: string,
    status: AttendanceStatus,
    missedMemorization = false,
    actor: AttendanceActor | null = null,
  ) {
    await this.assertCanRecord([studentId], actor);
    const actorUserId = actor?.id ?? null;
    const day = new Date(date);
    const { record, previous, charged } = await this.prisma.$transaction(
      async (tx) => {
        const before = await tx.attendance.findUnique({
          where: { studentId_date: { studentId, date: day } },
          select: { status: true },
        });
        const written = await tx.attendance.upsert({
          where: { studentId_date: { studentId, date: day } },
          update: { status, missedMemorization },
          create: { studentId, date: day, status, missedMemorization },
        });
        await this.clearMemorizationIfAbsent(tx, studentId, day, status);
        const charged = await this.reconcileFines(
          tx,
          studentId,
          day,
          status,
          missedMemorization,
          actorUserId,
        );
        return { record: written, previous: before?.status ?? null, charged };
      },
    );

    await this.notifyGuardians([{ studentId, status, previous, charged }]);
    return record;
  }

  async findByStudent(studentId: number) {
    return this.prisma.attendance.findMany({
      where: { studentId },
      orderBy: { date: 'desc' },
    });
  }

  async findByDate(date: string) {
    return this.prisma.attendance.findMany({
      where: { date: new Date(date) },
      include: {
        student: {
          include: { user: { select: { fullName: true, avatar: true } } },
        },
      },
      orderBy: { student: { user: { fullName: 'asc' } } },
    });
  }

  async update(
    id: number,
    dto: UpdateAttendanceDto,
    actor: AttendanceActor | null = null,
  ) {
    // The route names an attendance row, not a student, so who it belongs to
    // has to be looked up before the ownership rule can be applied. A missing
    // row needs no check — the update below fails on its own.
    const existing = await this.prisma.attendance.findUnique({
      where: { id },
      select: { studentId: true },
    });
    if (existing) await this.assertCanRecord([existing.studentId], actor);
    const actorUserId = actor?.id ?? null;

    return this.prisma.$transaction(async (tx) => {
      // The dto may not carry a status at all, so the row that actually
      // resulted is what decides whether the cleanup and reconciliation apply.
      const record = await tx.attendance.update({ where: { id }, data: dto });
      await this.clearMemorizationIfAbsent(
        tx,
        record.studentId,
        record.date,
        record.status,
      );
      // No notifyGuardians here — a PATCH is a correction to an existing row,
      // not the kind of new event the parent needs pinged about — so there is
      // no transition list to attach the charged amount to.
      await this.reconcileFines(
        tx,
        record.studentId,
        record.date,
        record.status,
        record.missedMemorization,
        actorUserId,
      );
      return record;
    });
  }

  async getStudentAttendanceSummary(studentId: number) {
    const now = new Date();
    // Attendance.date is a bare DATE that Prisma stores at UTC midnight, so
    // the window is built in UTC too. A local-time window sits hours off those
    // values and silently drops the first or last day of the month.
    const startOfMonth = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1),
    );
    const endOfMonth = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0, 23, 59, 59, 999),
    );
    const inMonth = { gte: startOfMonth, lte: endOfMonth };

    const [
      present,
      absent,
      late,
      total,
      monthPresent,
      monthAbsent,
      monthLate,
      recent,
    ] = await Promise.all([
        this.prisma.attendance.count({
          where: { studentId, status: 'PRESENT' },
        }),
        this.prisma.attendance.count({ where: { studentId, status: 'ABSENT' } }),
        this.prisma.attendance.count({ where: { studentId, status: 'LATE' } }),
        this.prisma.attendance.count({ where: { studentId } }),
        this.prisma.attendance.count({
          where: { studentId, status: 'PRESENT', date: inMonth },
        }),
        this.prisma.attendance.count({
          where: { studentId, status: 'ABSENT', date: inMonth },
        }),
        this.prisma.attendance.count({
          where: { studentId, status: 'LATE', date: inMonth },
        }),
        // Newest first: the streak is the run ending at the latest record.
        this.prisma.attendance.findMany({
          where: { studentId },
          orderBy: { date: 'desc' },
          select: { status: true },
        }),
      ]);

    // Days attended in a row, counting back from the most recent record. LATE
    // continues it for the same reason it counts towards the rate — a student
    // who turned up late still turned up — so the streak and the rate on the
    // same screen cannot disagree about the same week.
    //
    // These are attendance rows, not calendar days: Halaqa carries no
    // schedule, so the server cannot tell a day off from a day missed.
    let currentStreak = 0;
    for (const record of recent) {
      if (record.status === 'ABSENT') break;
      currentStreak++;
    }

    // A student who turned up late still turned up: LATE counts as attendance,
    // never as an absence. It sits on the numerator of both rates so the
    // figures agree with the day-by-day record the parent reads them against.
    const attended = present + late;
    const monthAttended = monthPresent + monthLate;
    const monthTotal = monthAttended + monthAbsent;

    return {
      // All-time counts, kept as a breakdown so a caller can still tell a
      // punctual day from a late one.
      present,
      absent,
      late,
      total,
      rate: total > 0 ? Math.round((attended / total) * 100) : 0,

      // This month, for the parent dashboard card and attendance tab.
      month: now.getUTCMonth() + 1,
      monthPresent,
      monthAbsent,
      monthLate,
      monthRate:
        monthTotal > 0 ? Math.round((monthAttended / monthTotal) * 100) : 0,

      currentStreak,
    };
  }

  /**
   * The admin dashboard's weekly chart: one entry per school day of the
   * current week (Sunday to Thursday), oldest first. A day nobody was marked
   * on comes back with a null rate rather than 0, so the chart can show that
   * nothing is recorded yet instead of claiming a total absence.
   */
  async getWeeklyAttendanceRates() {
    const DAY_MS = 24 * 60 * 60 * 1000;
    const now = new Date();
    // Attendance.date is a bare DATE stored at UTC midnight, so the week is
    // walked in UTC too — a local-time week lands hours off those values.
    const todayUtc = Date.UTC(
      now.getUTCFullYear(),
      now.getUTCMonth(),
      now.getUTCDate(),
    );
    // getUTCDay() is 0 for Sunday, which is also the first school day here.
    const sunday = todayUtc - new Date(todayUtc).getUTCDay() * DAY_MS;
    const days = Array.from(
      { length: 5 },
      (_, i) => new Date(sunday + i * DAY_MS),
    );

    const rows = await this.prisma.attendance.groupBy({
      by: ['date', 'status'],
      where: { date: { gte: days[0], lte: days[days.length - 1] } },
      _count: { _all: true },
    });

    return days.map((day) => {
      const forDay = rows.filter((r) => r.date.getTime() === day.getTime());
      const countOf = (status: AttendanceStatus) =>
        forDay.find((r) => r.status === status)?._count._all ?? 0;

      // Same rule as everywhere else: a late arrival is attendance.
      const present =
        countOf(AttendanceStatus.PRESENT) + countOf(AttendanceStatus.LATE);
      const absent = countOf(AttendanceStatus.ABSENT);
      const total = present + absent;

      return {
        date: day.toISOString().slice(0, 10),
        present,
        absent,
        rate: total > 0 ? Math.round((present / total) * 100) : null,
      };
    });
  }
}
