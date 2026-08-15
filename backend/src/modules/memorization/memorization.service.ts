import { Injectable, BadRequestException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';
import { Memorization } from '@prisma/client';
import { MAX_AMOUNT, unitFor } from './progress-unit';

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

  async create(dto: CreateMemorizationDto) {
    // The column defaults to MEMORIZING when the client omits the type, so the
    // bound has to be checked against that same fallback.
    const type = dto.memorizationType ?? Memorization.MEMORIZING;
    this.assertAmountFitsUnit(type, dto.amountDone);

    return this.prisma.memorizationProgress.create({
      data: { ...dto, date: new Date() },
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
