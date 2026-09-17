import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateTeacherDto, UpdateTeacherDto } from './dto/teacher.dto';
import * as bcrypt from 'bcrypt';
import { Memorization } from '@prisma/client';

@Injectable()
export class TeachersService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    const teachers = await this.prisma.teacher.findMany({
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            avatar: true,
            isActive: true,
          },
        },
        halaqas: { select: { _count: { select: { students: true } } } },
        _count: { select: { halaqas: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });

    return teachers.map(({ halaqas, _count, ...rest }) => ({
      ...rest,
      _count: {
        halaqas: _count.halaqas,
        students: halaqas.reduce((sum, h) => sum + h._count.students, 0),
      },
    }));
  }

  async findOne(id: number) {
    const t = await this.prisma.teacher.findUnique({
      where: { id },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            email: true,
            phone: true,
            avatar: true,
            isActive: true,
            createdAt: true,
          },
        },
        halaqas: {
          select: {
            id: true,
            name: true,
            level: true,
            _count: { select: { students: true } },
          },
        },
      },
    });
    if (!t) throw new NotFoundException('المعلم غير موجود');

    const { halaqas, ...rest } = t;
    const studentCount = halaqas.reduce((sum, h) => sum + h._count.students, 0);

    return {
      ...rest,
      halaqas,
      _count: { students: studentCount, halaqas: halaqas.length },
    };
  }

  async create(dto: CreateTeacherDto) {
    const hash = await bcrypt.hash(dto.password, 10);
    const phone =
      dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : undefined;
    const email =
      dto.email && dto.email.trim() !== '' ? dto.email.trim() : undefined;

    const user = await this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        email,
        phone,
        passwordHash: hash,
        role: 'TEACHER',
        avatar: dto.avatar,
        teacher: {
          create: {},
        },
      },
      include: { teacher: true },
    });

    if (user.teacher) {
      return await this.findOne(user.teacher.id);
    }
    return user;
  }

  async update(id: number, dto: UpdateTeacherDto) {
    const teacher = await this.prisma.teacher.findUnique({ where: { id } });
    if (!teacher) throw new NotFoundException('المعلم غير موجود');

    const userUpdate: any = {};
    if (dto.fullName) userUpdate.fullName = dto.fullName;
    if (dto.email !== undefined) {
      userUpdate.email =
        dto.email && dto.email.trim() !== '' ? dto.email.trim() : null;
    }
    if (dto.phone !== undefined) {
      userUpdate.phone =
        dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : null;
    }
    if (dto.avatar) userUpdate.avatar = dto.avatar;
    if (dto.password)
      userUpdate.passwordHash = await bcrypt.hash(dto.password, 10);

    await this.prisma.user.update({
      where: { id: teacher.userId },
      data: userUpdate,
    });
    return await this.findOne(id);
  }

  async remove(id: number) {
    const teacher = await this.prisma.teacher.findUnique({ where: { id } });
    if (!teacher) throw new NotFoundException('المعلم غير موجود');
    // Hard delete — removing the user cascades to the teacher row AND to the
    // halaqas they own (halaqas_teacherId_fkey is ON DELETE CASCADE). Students
    // of those halaqas survive; their halaqaId is set to NULL.
    return this.prisma.user.delete({ where: { id: teacher.userId } });
  }

  // ─── Teacher Dashboard Aggregates ───────────────────────────────────────────

  async getTeacherAttendanceSummary(teacherId: number) {
    const now = new Date();
    // Attendance.date is a bare DATE that Prisma stores at UTC midnight, so
    // the window is built in UTC too. A local-time window sits hours off those
    // values and silently drops the first or last day of the month — which a
    // percentage hid and a day count does not.
    const startOfMonth = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1),
    );
    const endOfMonth = new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 0, 23, 59, 59, 999),
    );

    const students = await this.prisma.student.findMany({
      where: { halaqa: { teacherId } },
      select: { id: true },
    });
    const studentIds = students.map((s) => s.id);

    if (studentIds.length === 0) {
      return { present: 0, absent: 0, rate: 0, month: now.getUTCMonth() + 1 };
    }

    // `present` covers everyone who turned up, late ones included: a late
    // student is not an absence, and the dashboard shows this count beside the
    // absences as the two halves of the month.
    const [present, absent] = await Promise.all([
      this.prisma.attendance.count({
        where: {
          studentId: { in: studentIds },
          status: { in: ['PRESENT', 'LATE'] },
          date: { gte: startOfMonth, lte: endOfMonth },
        },
      }),
      this.prisma.attendance.count({
        where: {
          studentId: { in: studentIds },
          status: 'ABSENT',
          date: { gte: startOfMonth, lte: endOfMonth },
        },
      }),
    ]);

    const total = present + absent;
    const rate = total > 0 ? Math.round((present / total) * 100) : 0;

    return { present, absent, rate, month: now.getUTCMonth() + 1 };
  }

  async getRevisionNeeded(teacherId: number) {
    const students = await this.prisma.student.findMany({
      where: { halaqa: { teacherId } },
      include: {
        user: { select: { fullName: true, avatar: true } },
        halaqa: { select: { name: true } },
        memorization: { orderBy: { recordedAt: 'desc' }, take: 1 },
      },
    });

    const now = new Date();
    const result: {
      id: number;
      name: string;
      avatar: string | null;
      halaqa: string | null;
      lastMemorizationDate: string | null;
      daysWithoutMemorization: number;
    }[] = [];

    for (const student of students) {
      const lastRecord = student.memorization[0];
      let daysWithout = 999; // never memorized
      let lastDate: string | null = null;

      if (lastRecord) {
        const diff = now.getTime() - new Date(lastRecord.recordedAt).getTime();
        daysWithout = Math.floor(diff / (1000 * 60 * 60 * 24));
        lastDate = lastRecord.recordedAt.toISOString();
      }

      if (daysWithout >= 2) {
        result.push({
          id: student.id,
          name: student.user.fullName,
          avatar: student.user.avatar,
          halaqa: student.halaqa?.name ?? null,
          lastMemorizationDate: lastDate,
          daysWithoutMemorization: daysWithout,
        });
      }
    }

    return result.sort(
      (a, b) => b.daysWithoutMemorization - a.daysWithoutMemorization,
    );
  }

  async getMemorizationProgress(teacherId: number) {
    const students = await this.prisma.student.findMany({
      where: { halaqa: { teacherId } },
      select: {
        id: true,
        finishedMemo: true,
        memorization: {
          take: 1,
          orderBy: { recordedAt: 'desc' },
        },
      },
    });

    const total = students.length;
    if (total === 0) {
      return {
        memorizingCount: 0,
        minorReviewCount: 0,
        majorReviewCount: 0,
        studentsCount: 0,
      };
    }

    let memorizing = 0; // no revision records yet
    let minorReview = 0; // has SMALLREVISION records
    let majorReview = 0; // finishedMemo = true

    for (const s of students) {
      if (s.finishedMemo) {
        majorReview++;
      } else {
        const hasRevision = s.memorization.some(
          (m: { memorizationType: Memorization }) =>
            m.memorizationType === Memorization.SMALLREVISION ||
            m.memorizationType === Memorization.BIGREVISION,
        );
        if (hasRevision) {
          minorReview++;
        } else {
          memorizing++;
        }
      }
    }

    return {
      memorizingCount: memorizing,
      minorReviewCount: minorReview,
      majorReviewCount: majorReview,
      studentsCount: total,
    };
  }
}
