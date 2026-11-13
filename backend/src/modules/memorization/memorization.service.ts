import {
  Injectable,
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';
import {
  AttendanceStatus,
  Memorization,
  MemorizationSubject,
} from '@prisma/client';
import {
  MAX_AMOUNT,
  ProgressUnit,
  ayahRangeAmount,
  unitFor,
} from './progress-unit';
import { reconcileDayFines } from '../attendance/day-fines';
import { isAway } from '../attendance/attendance-status';
import { reconcileDayPoints } from '../points/day-points';

/// Who is deleting a recitation. Same shape as AttendanceActor: the teacher id
/// is what decides whether the student is hers.
export type MemorizationActor = {
  id: number;
  role: string;
  teacher?: { id: number } | null;
};

// Attendance rows are written as new Date('YYYY-MM-DD'), which parses to UTC
// midnight, and both date columns are @db.Date, which Prisma truncates in UTC.
// Flooring the same way is what lets a lookup find the row the teacher just
// wrote.
function startOfUtcDay(instant: Date): Date {
  const date = new Date(instant);
  date.setUTCHours(0, 0, 0, 0);
  return date;
}

/** Stable reason codes the app matches on. Never reuse or renumber these. */
export const MEMORIZATION_ERROR = {
  STUDENT_ABSENT: 'STUDENT_ABSENT',
  HADITH_NOT_ENABLED: 'HADITH_NOT_ENABLED',
  HADITH_BOOK_NOT_ASSIGNED: 'HADITH_BOOK_NOT_ASSIGNED',
} as const;

@Injectable()
export class MemorizationService {
  constructor(private prisma: PrismaService) {}

  private assertAmountFitsUnit(unit: ProgressUnit, amountDone: number) {
    // A half page is a real recitation; a half hadith or ayah is not
    // recorded, and nothing finer than a half is ever meant (1.3 is a typo).
    const step = unit === 'PAGE' ? 0.5 : 1;
    if (!Number.isInteger(amountDone / step) || amountDone < step) {
      throw new BadRequestException(
        unit === 'PAGE'
          ? 'PAGE amounts go in steps of 0.5, so amountDone must be like 1, 1.5 or 2'
          : `${unit} amounts are whole numbers, so amountDone must be a whole number of at least 1`,
      );
    }
    const max = MAX_AMOUNT[unit];
    if (amountDone > max) {
      throw new BadRequestException(
        `${unit} is recorded per entry with a limit of ${max}, so amountDone must be at most ${max}`,
      );
    }
  }

  // A QURAN row may name its surah but does not have to: a teacher can record
  // "3 pages" without saying which. A HADITH row identifies itself with free
  // text instead — there is no fixed hadith list to pick a number from — and
  // that reference is required. Each subject rejects the other's identity
  // field, so a row never carries both.
  private assertSubjectFields(
    subject: MemorizationSubject,
    surahNumber: number | null | undefined,
    hadithReference: string | null | undefined,
  ) {
    if (subject === MemorizationSubject.QURAN) {
      if (hadithReference) {
        throw new BadRequestException(
          'hadithReference is not valid for a Quran entry',
        );
      }
    } else {
      if (!hadithReference || !hadithReference.trim()) {
        throw new BadRequestException(
          'hadithReference is required for a hadith entry',
        );
      }
      if (surahNumber != null) {
        throw new BadRequestException(
          'surahNumber is not valid for a hadith entry',
        );
      }
    }
  }

  // Hadith tracking is opt-in per student, set by the admin. A HADITH write
  // for a student without it enabled would create progress for a track the
  // admin never turned on, so this is checked at write time rather than
  // trusted from the client. A write that names a book must also name one the
  // admin assigned. `book` is undefined when an edit keeps the row's existing
  // reference, so an entry typed as free text before the book list existed
  // can still have its amount corrected.
  private async assertHadithEnabled(studentId: number, book?: string | null) {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { tracksHadith: true, hadithBooks: true },
    });
    if (!student?.tracksHadith) {
      throw new BadRequestException({
        statusCode: 400,
        error: 'Bad Request',
        code: MEMORIZATION_ERROR.HADITH_NOT_ENABLED,
        message: 'This student does not have hadith memorization enabled',
      });
    }
    const assigned = Array.isArray(student.hadithBooks)
      ? student.hadithBooks
      : [];
    if (book != null && !assigned.includes(book)) {
      throw new BadRequestException({
        statusCode: 400,
        error: 'Bad Request',
        code: MEMORIZATION_ERROR.HADITH_BOOK_NOT_ASSIGNED,
        message: 'This hadith book is not assigned to this student',
      });
    }
  }

  // A student who was not in the halaqa cannot have recited in it. The teacher
  // records attendance and memorization on the same screen, so the two can
  // contradict each other unless the write is refused here.
  private async assertNotAbsent(
    studentId: number,
    date: Date,
  ): Promise<AttendanceStatus | null> {
    const attendance = await this.prisma.attendance.findUnique({
      where: { studentId_date: { studentId, date } },
      select: { status: true },
    });

    // Attendance not taken yet is not the same as being absent, so only an
    // explicit day away (ABSENT or EXCUSED) blocks the record. LATE still
    // means the student showed up.
    if (isAway(attendance?.status)) {
      // Every rejection on this route is a 400, so the status alone cannot tell
      // the app that absence is what blocked it. The reason travels as a stable
      // code rather than as prose the client would have to pattern-match.
      throw new BadRequestException({
        statusCode: 400,
        error: 'Bad Request',
        code: MEMORIZATION_ERROR.STUDENT_ABSENT,
        message:
          'Cannot record memorization for a student marked absent on this date',
      });
    }
    return attendance?.status ?? null;
  }

  async create(dto: CreateMemorizationDto) {
    // The column defaults to QURAN when the client omits the subject, so
    // every existing caller keeps recording Quran progress unchanged.
    const subject = dto.subject ?? MemorizationSubject.QURAN;

    this.assertSubjectFields(subject, dto.surahNumber, dto.hadithReference);
    const unit = unitFor(subject, dto.unit);
    this.assertAmountFitsUnit(unit, dto.amountDone);
    ayahRangeAmount({ unit, ...dto });
    if (subject === MemorizationSubject.HADITH) {
      await this.assertHadithEnabled(dto.studentId, dto.hadithReference);
    }

    // Attendance.date is a bare DATE, so the timestamp has to be floored to
    // midnight to line up with the row the teacher just wrote.
    const date = startOfUtcDay(new Date());
    // A recitation outside the session has nothing to do with today's roll
    // call: it is not refused for an absent student and never reconciles the
    // day's fines, so attendance is not even read.
    const outsideSession = dto.outsideSession ?? false;
    const attendance = outsideSession
      ? null
      : await this.assertNotAbsent(dto.studentId, date);

    return this.prisma.$transaction(async (tx) => {
      const record = await tx.memorizationProgress.create({
        data: { ...dto, subject, unit, date, outsideSession },
      });
      // A recitation is what clears the day's "did not memorize" charge, so
      // the day is reconciled in the same write. With no attendance yet there
      // is nothing to reconcile: the charge only exists once roll is taken.
      if (attendance) {
        await reconcileDayFines(tx, dto.studentId, date, attendance, null);
      }
      // Unlike fines, points follow a recitation with or without roll call:
      // the pages were recited either way.
      await reconcileDayPoints(tx, dto.studentId, date);
      return record;
    });
  }

  async findByStudent(studentId: number) {
    return this.prisma.memorizationProgress.findMany({
      where: { studentId },
      orderBy: [{ surahNumber: 'asc' }],
    });
  }

  async findByDate(date: string) {
    return this.prisma.memorizationProgress.findMany({
      where: { date: new Date(date) }, // exact match, no range needed
    });
  }

  async update(id: number, dto: UpdateMemorizationDto) {
    const existing = await this.prisma.memorizationProgress.findUnique({
      where: { id },
    });
    if (!existing) {
      throw new NotFoundException(`No memorization progress with id ${id}`);
    }

    // Any field of the subject/surah/hadith/type/amount group can arrive
    // alone, so validate the combination the row will actually end up with.
    const subject = dto.subject ?? existing.subject;
    const surahNumber =
      dto.surahNumber !== undefined ? dto.surahNumber : existing.surahNumber;
    const hadithReference =
      dto.hadithReference !== undefined
        ? dto.hadithReference
        : existing.hadithReference;

    this.assertSubjectFields(subject, surahNumber, hadithReference);
    // An edit that moves the row to the other subject starts from that
    // subject's default unit; otherwise the row keeps the unit it has.
    const keptUnit = subject === existing.subject ? existing.unit : undefined;
    const unit = unitFor(subject, dto.unit ?? keptUnit);
    // A row that stays in ayahs keeps whichever end of its range the edit
    // leaves alone; a row leaving ayahs drops its range. An edit that only
    // moves the range recounts the amount from it, so "ayahs 1–5 → 1–10"
    // needs no amount alongside.
    // A range only exists inside a surah, so clearing the surah drops it too.
    const staysAyah =
      unit === ProgressUnit.AYAH &&
      existing.unit === ProgressUnit.AYAH &&
      surahNumber != null;
    const ayahFrom = staysAyah
      ? (dto.ayahFrom ?? existing.ayahFrom)
      : dto.ayahFrom;
    const ayahTo = staysAyah ? (dto.ayahTo ?? existing.ayahTo) : dto.ayahTo;
    const rangeMoved = dto.ayahFrom !== undefined || dto.ayahTo !== undefined;
    const amountDone =
      dto.amountDone ??
      (unit === ProgressUnit.AYAH &&
      rangeMoved &&
      ayahFrom != null &&
      ayahTo != null
        ? ayahTo - ayahFrom + 1
        : existing.amountDone);
    this.assertAmountFitsUnit(unit, amountDone);
    ayahRangeAmount({ unit, surahNumber, ayahFrom, ayahTo, amountDone });
    if (subject === MemorizationSubject.HADITH) {
      await this.assertHadithEnabled(existing.studentId, dto.hadithReference);
    }

    // A changed amount or type changes what the day is worth, so the day's
    // points are reconciled in the same write. The date and student cannot be
    // edited, so the row's own day is the only one affected.
    return this.prisma.$transaction(async (tx) => {
      const record = await tx.memorizationProgress.update({
        where: { id },
        data: {
          ...dto,
          unit,
          amountDone,
          // `?? null`, not the bare value: Prisma reads undefined as "leave
          // as is", which would keep a range on a row whose surah was cleared.
          ayahFrom: unit === ProgressUnit.AYAH ? (ayahFrom ?? null) : null,
          ayahTo: unit === ProgressUnit.AYAH ? (ayahTo ?? null) : null,
        },
      });
      await reconcileDayPoints(tx, existing.studentId, existing.date);
      return record;
    });
  }

  /// Removes a recitation recorded by mistake.
  ///
  /// The day is reckoned again in the same write: the points it earned go,
  /// and if roll was taken that day the "did not memorize" charge comes back
  /// when no other in-session recitation is left — it was this row that had
  /// cleared it. A teacher may only delete for students in her own halaqa;
  /// ADMIN is unrestricted.
  async remove(id: number, actor: MemorizationActor | null = null) {
    const existing = await this.prisma.memorizationProgress.findUnique({
      where: { id },
      select: {
        id: true,
        studentId: true,
        date: true,
        student: { select: { halaqa: { select: { teacherId: true } } } },
      },
    });
    if (!existing) throw new NotFoundException('سجل الحفظ غير موجود');

    if (actor?.role === 'TEACHER') {
      // Checked side by side rather than compared directly, so a missing
      // teacher profile and a student with no halaqa cannot both read as
      // undefined and pass.
      const teacherId = actor.teacher?.id;
      const owner = existing.student?.halaqa?.teacherId;
      if (teacherId == null || owner == null || owner !== teacherId) {
        throw new ForbiddenException('لا يمكنك حذف حفظ طالب من حلقة أخرى');
      }
    }

    const { studentId, date } = existing;
    await this.prisma.$transaction(async (tx) => {
      await tx.memorizationProgress.delete({ where: { id } });
      const attendance = await tx.attendance.findUnique({
        where: { studentId_date: { studentId, date } },
        select: { status: true },
      });
      // No roll call that day means no charge to bring back, the same rule
      // create follows.
      if (attendance) {
        await reconcileDayFines(
          tx,
          studentId,
          date,
          attendance.status,
          actor?.id ?? null,
        );
      }
      await reconcileDayPoints(tx, studentId, date);
    });
    return { deleted: true };
  }

  async getStudentProgress(studentId: number) {
    const records = await this.prisma.memorizationProgress.findMany({
      where: { studentId },
      orderBy: { recordedAt: 'desc' },
    });

    const quranRecords = records.filter(
      (r) => r.subject === MemorizationSubject.QURAN,
    );

    // Revision re-reads pages already memorized, so adding it would count
    // them twice. Only new Quran memorization contributes to the page total,
    // and hadith rows are excluded entirely — there is no "% of Quran"
    // meaning for them.
    // Pages and ayahs are different units, so an ayah entry adds to its own
    // total and never to the page count.
    const newQuran = quranRecords.filter(
      (r) => r.memorizationType === Memorization.MEMORIZING,
    );
    const totalPagesDone = newQuran
      .filter((r) => r.unit !== ProgressUnit.AYAH)
      .reduce((sum, r) => sum + r.amountDone, 0);
    const totalAyahsDone = newQuran
      .filter((r) => r.unit === ProgressUnit.AYAH)
      .reduce((sum, r) => sum + r.amountDone, 0);
    // An entry recorded without a surah touched no particular surah.
    const totalSurahs = new Set(
      quranRecords.map((r) => r.surahNumber).filter((n) => n != null),
    ).size;

    // Single hadiths and hadith pages are different units, so each gets its
    // own total rather than being added together.
    const newHadith = records.filter(
      (r) =>
        r.subject === MemorizationSubject.HADITH &&
        r.memorizationType === Memorization.MEMORIZING,
    );
    const sumIn = (unit: ProgressUnit) =>
      newHadith
        .filter((r) => unitFor(r.subject, r.unit) === unit)
        .reduce((sum, r) => sum + r.amountDone, 0);
    const totalHadithsDone = sumIn(ProgressUnit.HADITH);
    const totalHadithPagesDone = sumIn(ProgressUnit.PAGE);

    const countTypes = (rows: typeof records) =>
      rows.reduce(
        (acc, r) => {
          acc[r.memorizationType]++;
          return acc;
        },
        { MEMORIZING: 0, SMALLREVISION: 0, BIGREVISION: 0 } as Record<
          Memorization,
          number
        >,
      );
    const typeCounts = countTypes(quranRecords);
    const hadithTypeCounts = countTypes(
      records.filter((r) => r.subject === MemorizationSubject.HADITH),
    );

    // Lets the app show the hadith counters for a student who tracks hadith
    // but has no hadith entry yet.
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { tracksHadith: true },
    });

    return {
      records,
      totalPagesDone,
      totalAyahsDone,
      totalHadithsDone,
      totalHadithPagesDone,
      totalSurahs,
      typeCounts,
      hadithTypeCounts,
      tracksHadith: student?.tracksHadith ?? false,
    };
  }
}
