import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateEvaluationDto, UpdateEvaluationDto } from './dto/evaluation.dto';

@Injectable()
export class EvaluationsService {
  constructor(private prisma: PrismaService) {}

  private calculateOverall(
    mem?: number,
    taj?: number,
    flue?: number,
    disc?: number
  ): number | undefined {
    const scores = [mem, taj, flue, disc].filter((s): s is number => s !== undefined && s !== null);
    if (scores.length === 0) return undefined;
    const sum = scores.reduce((a, b) => a + b, 0);
    return Math.round((sum / scores.length) * 100) / 100;
  }

  async create(dto: CreateEvaluationDto) {
    let overall = dto.overallScore;
    if (overall === undefined || overall === null) {
      overall = this.calculateOverall(
        dto.memorizationScore,
        dto.tajweedScore,
        dto.fluencyScore,
        dto.disciplineScore
      );
    }
    return this.prisma.evaluation.create({
      data: {
        ...dto,
        overallScore: overall,
      },
      include: {
        student: { include: { user: { select: { fullName: true } } } },
        teacher: { include: { user: { select: { fullName: true } } } },
      },
    });
  }

  async findByStudent(studentId: number) {
    return this.prisma.evaluation.findMany({
      where: { studentId },
      include: {
        teacher: { include: { user: { select: { fullName: true, avatar: true } } } },
      },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: number) {
    const evalRecord = await this.prisma.evaluation.findUnique({
      where: { id },
      include: {
        student: { include: { user: { select: { fullName: true, avatar: true } } } },
        teacher: { include: { user: { select: { fullName: true, avatar: true } } } },
      },
    });
    if (!evalRecord) throw new NotFoundException('التقييم غير موجود');
    return evalRecord;
  }

  async update(id: number, dto: UpdateEvaluationDto) {
    const existing = await this.prisma.evaluation.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('التقييم غير موجود');

    let overall = dto.overallScore;
    if (overall === undefined || overall === null) {
      const mem = dto.memorizationScore !== undefined ? dto.memorizationScore : (existing.memorizationScore ?? undefined);
      const taj = dto.tajweedScore !== undefined ? dto.tajweedScore : (existing.tajweedScore ?? undefined);
      const flue = dto.fluencyScore !== undefined ? dto.fluencyScore : (existing.fluencyScore ?? undefined);
      const disc = dto.disciplineScore !== undefined ? dto.disciplineScore : (existing.disciplineScore ?? undefined);
      overall = this.calculateOverall(mem, taj, flue, disc);
    }

    return this.prisma.evaluation.update({
      where: { id },
      data: {
        ...dto,
        overallScore: overall,
      },
      include: {
        student: { include: { user: { select: { fullName: true } } } },
        teacher: { include: { user: { select: { fullName: true } } } },
      },
    });
  }

  async remove(id: number) {
    const existing = await this.prisma.evaluation.findUnique({ where: { id } });
    if (!existing) throw new NotFoundException('التقييم غير موجود');
    return this.prisma.evaluation.delete({ where: { id } });
  }
}
