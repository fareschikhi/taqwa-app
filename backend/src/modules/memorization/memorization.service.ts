import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
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
import { MAX_AMOUNT, unitFor } from './progress-unit';

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

  private assertAmountFitsUnit(
    subject: MemorizationSubject,
    type: Memorization,
    amountDone: number,
  ) {
    const unit = unitFor(subject, type);
    const max = MAX_AMOUNT[unit];
    if (amountDone > max) {
      throw new BadRequestException(
        `${unit} is recorded per entry with a limit of ${max}, so amountDone must be at most ${max}`,
      );
    }
  }

  // A QURAN row identifies its surah; a HADITH row identifies itself with
  // free text instead — there is no fixed hadith list to pick a number from.
  // Each subject rejects the other's identity field, so a row can never
  // carry both or neither.
  private assertSubjectFields(
    subject: MemorizationSubject,
    surahNumber: number | null | undefined,
    hadithReference: string | null | undefined,
  ) {
    if (subject === MemorizationSubject.QURAN) {
      if (surahNumber == null) {
        throw new BadRequestException(
          'surahNumber is required for a Quran entry',
        );
      }
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
  private async assertNotAbsent(studentId: number, date: Date) {
    const attendance = await this.prisma.attendance.findUnique({
      where: { studentId_date: { studentId, date } },
      select: { status: true },
    });

    // Attendance not taken yet is not the same as being absent, so only an
    // explicit ABSENT blocks the record. LATE still means the student showed up.
    if (attendance?.status === AttendanceStatus.ABSENT) {
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
  }

  async create(dto: CreateMemorizationDto) {
    // The column defaults to QURAN when the client omits the subject, so
    // every existing caller keeps recording Quran progress unchanged.
    const subject = dto.subject ?? MemorizationSubject.QURAN;
    // The column defaults to MEMORIZING when the client omits the type, so the
    // bound has to be checked against that same fallback.
    const type = dto.memorizationType ?? Memorization.MEMORIZING;

    this.assertSubjectFields(subject, dto.surahNumber, dto.hadithReference);
    this.assertAmountFitsUnit(subject, type, dto.amountDone);
    if (subject === MemorizationSubject.HADITH) {
      await this.assertHadithEnabled(dto.studentId, dto.hadithReference);
    }

    // Attendance.date is a bare DATE, so the timestamp has to be floored to
    // midnight to line up with the row the teacher just wrote.
    const date = startOfUtcDay(new Date());
    await this.assertNotAbsent(dto.studentId, date);

    return this.prisma.memorizationProgress.create({
      data: { ...dto, subject, date },
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
    this.assertAmountFitsUnit(
      subject,
      dto.memorizationType ?? existing.memorizationType,
      dto.amountDone ?? existing.amountDone,
    );
    if (subject === MemorizationSubject.HADITH) {
      await this.assertHadithEnabled(existing.studentId, dto.hadithReference);
    }

    return this.prisma.memorizationProgress.update({
      where: { id },
      data: dto,
    });
  }

  async getStudentProgress(studentId: number) {
    const records = await this.prisma.memorizationProgress.findMany({
      where: { studentId },
      orderBy: { recordedAt: 'desc' },
    });

    const quranRecords = records.filter(
      (r) => r.subject === MemorizationSubject.QURAN,
    );

    // Revision amounts are hizbs, so they cannot be added to page counts.
    // Only new Quran memorization contributes to the page total, and hadith
    // rows are excluded entirely — there is no "% of Quran" meaning for them.
    const totalPagesDone = quranRecords
      .filter((r) => r.memorizationType === Memorization.MEMORIZING)
      .reduce((sum, r) => sum + r.amountDone, 0);
    const totalSurahs = new Set(quranRecords.map((r) => r.surahNumber)).size;

    const totalHadithsDone = records
      .filter(
        (r) =>
          r.subject === MemorizationSubject.HADITH &&
          r.memorizationType === Memorization.MEMORIZING,
      )
      .reduce((sum, r) => sum + r.amountDone, 0);

    const typeCounts = quranRecords.reduce(
      (acc, r) => {
        acc[r.memorizationType]++;
        return acc;
      },
      { MEMORIZING: 0, SMALLREVISION: 0, BIGREVISION: 0 } as Record<
        Memorization,
        number
      >,
    );

    return { records, totalPagesDone, totalHadithsDone, totalSurahs, typeCounts };
  }
}
