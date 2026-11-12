import { Injectable, NotFoundException } from '@nestjs/common';
import { AttendanceStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { reconcileDayPoints } from '../points/day-points';
import {
  CreateAbsenceJustificationDto,
  UpdateAbsenceJustificationDto,
} from './dto/absence-justification.dto';

@Injectable()
export class AbsenceJustificationService {
  constructor(private prisma: PrismaService) {}

  /// The student's halaqa rides along so the manager's lists can group rows by
  /// circle without a lookup per halaqa.
  private readonly student = {
    include: {
      user: { select: { id: true, fullName: true, avatar: true } },
      halaqa: { select: { id: true, name: true } },
    },
  };

  private readonly include = {
    student: this.student,
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

  /// Absent/late attendance rows that nobody has justified yet: the manager's
  /// students, or every student when [managerId] is left out (the admin's
  /// school-wide view). Answering this in one query keeps callers from
  /// walking every student's attendance client-side.
  async findUnjustified(managerId?: number) {
    return this.prisma.attendance.findMany({
      where: {
        status: { in: [AttendanceStatus.ABSENT, AttendanceStatus.LATE] },
        justification: { is: null },
        ...(managerId === undefined
          ? {}
          : { student: await this.managerScope(managerId) }),
      },
      include: { student: this.student },
      orderBy: { date: 'desc' },
    });
  }

  /// The students a manager covers: their halaqas, plus the students in no
  /// halaqa when they may see those.
  private async managerScope(managerId: number) {
    const manager = await this.prisma.manager.findUnique({
      where: { id: managerId },
      include: { halaqas: { select: { halaqaId: true } } },
    });
    if (!manager) throw new NotFoundException('المدير غير موجود');

    return {
      OR: [
        { halaqaId: { in: manager.halaqas.map((h) => h.halaqaId) } },
        ...(manager.canAccessUnassigned ? [{ halaqaId: null }] : []),
      ],
    };
  }

  /// With [ownerId] (a signed-in manager) only that manager's own excuses are
  /// found; anyone else's reads as missing, so ids can't be probed.
  async findOne(id: number, ownerId?: number) {
    const j = await this.prisma.absenceJustification.findUnique({
      where: { id },
      include: this.include,
    });
    if (!j || (ownerId !== undefined && j.managerId !== ownerId)) {
      throw new NotFoundException('التبرير غير موجود');
    }
    return j;
  }

  /// With [scopeManagerId] (a signed-in manager) the absence must belong to
  /// a student that manager covers.
  async create(dto: CreateAbsenceJustificationDto, scopeManagerId?: number) {
    if (scopeManagerId !== undefined) {
      const inScope = await this.prisma.attendance.findFirst({
        where: {
          id: dto.attendanceId,
          student: await this.managerScope(scopeManagerId),
        },
        select: { id: true },
      });
      if (!inScope) throw new NotFoundException('سجل الحضور غير موجود');
    }

    // An excused absence costs no points, so recording the excuse reconciles
    // the absent day in the same write. The day comes from the attendance row
    // itself rather than the dto, which only names it.
    return this.prisma.$transaction(async (tx) => {
      const attendance = await tx.attendance.findUnique({
        where: { id: dto.attendanceId },
        select: { studentId: true, date: true },
      });
      const justification = await tx.absenceJustification.create({
        data: {
          // The attendance row says whose absence it is; a mismatched
          // studentId in the body must not file the excuse under someone else.
          studentId: attendance?.studentId ?? dto.studentId,
          attendanceId: dto.attendanceId,
          managerId: dto.managerId,
          reasonType: dto.reasonType,
          customReason: dto.customReason,
          notes: dto.notes,
        },
        include: this.include,
      });
      if (attendance) {
        await reconcileDayPoints(tx, attendance.studentId, attendance.date);
      }
      return justification;
    });
  }

  /// With [ownerId] (a signed-in manager) only their own excuses can change.
  async update(
    id: number,
    dto: UpdateAbsenceJustificationDto,
    ownerId?: number,
  ) {
    const j = await this.prisma.absenceJustification.findUnique({
      where: { id },
    });
    if (!j || (ownerId !== undefined && j.managerId !== ownerId)) {
      throw new NotFoundException('التبرير غير موجود');
    }

    return this.prisma.absenceJustification.update({
      where: { id },
      data: dto,
      include: this.include,
    });
  }
}
