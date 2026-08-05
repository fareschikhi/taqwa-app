import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateAttendanceDto,
  CreateBatchAttendanceDto,
  UpdateAttendanceDto,
} from './dto/attendance.dto';
import { AttendanceStatus } from '@prisma/client/wasm';

@Injectable()
export class AttendanceService {
  constructor(private prisma: PrismaService) {}

  async create(dto: CreateAttendanceDto) {
    return this.prisma.attendance.upsert({
      where: {
        studentId_date: { studentId: dto.studentId, date: new Date(dto.date) },
      },
      update: { status: dto.status, notes: dto.notes },
      create: {
        studentId: dto.studentId,
        date: new Date(dto.date),
        status: dto.status,
        notes: dto.notes,
      },
    });
  }

  async createBatch(dto: CreateBatchAttendanceDto) {
    const results = await this.prisma.$transaction(
      dto.records.map((r) =>
        this.prisma.attendance.upsert({
          where: {
            studentId_date: { studentId: r.studentId, date: new Date(r.date) },
          },
          update: { status: r.status, notes: r.notes },
          create: {
            studentId: r.studentId,
            date: new Date(r.date),
            status: r.status,
            notes: r.notes,
          },
        }),
      ),
    );
    return { count: results.length, records: results };
  }

  async upsert(studentId: number, date: string, status: AttendanceStatus) {
    return this.prisma.attendance.upsert({
      where: { studentId_date: { studentId, date: new Date(date) } },
      update: { status },
      create: { studentId, date: new Date(date), status },
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
    return this.prisma.attendance.update({ where: { id }, data: dto });
  }

  async getStudentAttendanceSummary(studentId: number) {
    const [present, absent, late, total] = await Promise.all([
      this.prisma.attendance.count({ where: { studentId, status: 'PRESENT' } }),
      this.prisma.attendance.count({ where: { studentId, status: 'ABSENT' } }),
      this.prisma.attendance.count({ where: { studentId, status: 'LATE' } }),
      this.prisma.attendance.count({ where: { studentId } }),
    ]);
    return {
      present,
      absent,
      late,
      total,
      rate: total > 0 ? Math.round((present / total) * 100) : 0,
    };
  }
}
