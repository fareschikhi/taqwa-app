import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateAttendanceDto,
  CreateBatchAttendanceDto,
  UpdateAttendanceDto,
} from './dto/attendance.dto';
import { AttendanceStatus, Prisma } from '@prisma/client';

@Injectable()
export class AttendanceService {
  constructor(private prisma: PrismaService) {}

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

  async create(dto: CreateAttendanceDto) {
    const date = new Date(dto.date);
    return this.prisma.$transaction(async (tx) => {
      const record = await tx.attendance.upsert({
        where: { studentId_date: { studentId: dto.studentId, date } },
        update: { status: dto.status, notes: dto.notes },
        create: {
          studentId: dto.studentId,
          date,
          status: dto.status,
          notes: dto.notes,
        },
      });
      await this.clearMemorizationIfAbsent(tx, dto.studentId, date, dto.status);
      return record;
    });
  }

  async createBatch(dto: CreateBatchAttendanceDto) {
    const records = await this.prisma.$transaction(async (tx) => {
      const written: Array<Awaited<ReturnType<typeof tx.attendance.upsert>>> =
        [];
      for (const r of dto.records) {
        const date = new Date(r.date);
        written.push(
          await tx.attendance.upsert({
            where: { studentId_date: { studentId: r.studentId, date } },
            update: { status: r.status, notes: r.notes },
            create: {
              studentId: r.studentId,
              date,
              status: r.status,
              notes: r.notes,
            },
          }),
        );
        await this.clearMemorizationIfAbsent(tx, r.studentId, date, r.status);
      }
      return written;
    });
    return { count: records.length, records };
  }

  async upsert(studentId: number, date: string, status: AttendanceStatus) {
    const day = new Date(date);
    return this.prisma.$transaction(async (tx) => {
      const record = await tx.attendance.upsert({
        where: { studentId_date: { studentId, date: day } },
        update: { status },
        create: { studentId, date: day, status },
      });
      await this.clearMemorizationIfAbsent(tx, studentId, day, status);
      return record;
    });
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

  async update(id: number, dto: UpdateAttendanceDto) {
    return this.prisma.$transaction(async (tx) => {
      // The dto may not carry a status at all, so the row that actually
      // resulted is what decides whether the cleanup applies.
      const record = await tx.attendance.update({ where: { id }, data: dto });
      await this.clearMemorizationIfAbsent(
        tx,
        record.studentId,
        record.date,
        record.status,
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

    const [present, absent, late, total, monthPresent, monthAbsent, monthLate] =
      await Promise.all([
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
      ]);

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
