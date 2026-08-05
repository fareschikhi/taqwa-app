import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateAbsenceJustificationDto,
  UpdateAbsenceJustificationDto,
} from './dto/absence-justification.dto';

@Injectable()
export class AbsenceJustificationService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
    student: {
      include: {
        user: { select: { id: true, fullName: true, avatar: true } },
      },
    },
    attendance: {
      select: { id: true, date: true, status: true },
    },
    manager: {
      include: {
        user: { select: { id: true, fullName: true } },
      },
    },
  };

  async findAll(managerId?: number, studentId?: number) {
    return this.prisma.absenceJustification.findMany({
      where: {
        ...(managerId ? { managerId } : {}),
        ...(studentId ? { studentId } : {}),
      },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: number) {
    const j = await this.prisma.absenceJustification.findUnique({
      where: { id },
      include: this.include,
    });
    if (!j) throw new NotFoundException('التبرير غير موجود');
    return j;
  }

  async create(dto: CreateAbsenceJustificationDto) {
    return this.prisma.absenceJustification.create({
      data: {
        studentId: dto.studentId,
        attendanceId: dto.attendanceId,
        managerId: dto.managerId,
        reasonType: dto.reasonType,
        customReason: dto.customReason,
        notes: dto.notes,
      },
      include: this.include,
    });
  }

  async update(id: number, dto: UpdateAbsenceJustificationDto) {
    const j = await this.prisma.absenceJustification.findUnique({
      where: { id },
    });
    if (!j) throw new NotFoundException('التبرير غير موجود');

    return this.prisma.absenceJustification.update({
      where: { id },
      data: dto,
      include: this.include,
    });
  }
}
