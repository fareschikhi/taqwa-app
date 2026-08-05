import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';
import { Memorization } from '@prisma/client';

@Injectable()
export class MemorizationService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateMemorizationDto) {
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

    const totalPagesDone = records.reduce((sum, r) => sum + r.pagesDone, 0);
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
