import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';
import { AttendanceStatus, Memorization } from '@prisma/client';
import { MAX_AMOUNT, unitFor } from './progress-unit';

// Attendance rows are written as new Date('YYYY-MM-DD'), which parses to UTC
// midnight, and both date columns are @db.Date, which Prisma truncates in UTC.
// Flooring the same way is what lets a lookup find the row the teacher wrote.
function startOfUtcDay(instant: Date): Date {
  const date = new Date(instant);
  date.setUTCHours(0, 0, 0, 0);
  return date;
}

/** Stable reason codes the app matches on. Never reuse or renumber these. */
export const MEMORIZATION_ERROR = {
  STUDENT_ABSENT: 'STUDENT_ABSENT',
} as const;

@Injectable()
export class MemorizationService {
  constructor(private prisma: PrismaService) {}

  private assertAmountFitsUnit(type: Memorization, amountDone: number) {
    const unit = unitFor(type);
    const max = MAX_AMOUNT[unit];
    if (amountDone > max) {
      throw new BadRequestException(
        `${type} is recorded in ${unit}S, so amountDone must be at most ${max}`,
      );
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
    // The column defaults to MEMORIZING when the client omits the type, so the
    // bound has to be checked against that same fallback.
    const type = dto.memorizationType ?? Memorization.MEMORIZING;
    this.assertAmountFitsUnit(type, dto.amountDone);

    // Attendance.date is a bare DATE, so the timestamp has to be floored to
    // midnight to line up with the row the teacher just wrote.
    const date = startOfUtcDay(new Date());
    await this.assertNotAbsent(dto.studentId, date);

    return this.prisma.memorizationProgress.create({
      data: { ...dto, date },
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

    // Either half of the type/amount pair can arrive alone, so validate the
    // combination the row will actually end up with. Switching a page-counted
    // entry to a revision can otherwise leave an impossible hizb count behind.
    this.assertAmountFitsUnit(
      dto.memorizationType ?? existing.memorizationType,
      dto.amountDone ?? existing.amountDone,
    );

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

    // Revision amounts are hizbs, so they cannot be added to page counts.
    // Only new memorization contributes to the page total.
    const totalPagesDone = records
      .filter((r) => r.memorizationType === Memorization.MEMORIZING)
      .reduce((sum, r) => sum + r.amountDone, 0);
    const totalSurahs = new Set(records.map((r) => r.surahNumber)).size;

    const typeCounts = records.reduce(
      (acc, r) => {
        acc[r.memorizationType]++;
        return acc;
      },
      { MEMORIZING: 0, SMALLREVISION: 0, BIGREVISION: 0 } as Record<
        Memorization,
        number
      >,
    );

    return { records, totalPagesDone, totalSurahs, typeCounts };
  }
}
