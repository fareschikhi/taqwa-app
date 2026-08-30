import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStudentDto, UpdateStudentDto } from './dto/student.dto';

@Injectable()
export class StudentsService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
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
    halaqa: {
      select: {
        id: true,
        name: true,
        level: true,
        teacher: { select: { user: { select: { fullName: true } } } },
      },
    },
    _count: {
      select: { attendance: true, memorization: true, evaluations: true },
    },
  };

  async findAll(params?: {
    teacherId?: number;
    halaqaId?: number;
    search?: string;
    page?: number;
    limit?: number;
    isActive?: boolean;
  }) {
    const page = params?.page ?? 1;
    const limit = params?.limit ?? 50;
    const skip = (page - 1) * limit;

    const whereConditions: any[] = [];

    if (params?.teacherId !== undefined) {
      whereConditions.push({ halaqa: { teacherId: params.teacherId } });
    }
    if (params?.halaqaId !== undefined) {
      whereConditions.push({ halaqaId: params.halaqaId });
    }
    if (params?.isActive !== undefined) {
      whereConditions.push({ user: { isActive: params.isActive } });
    }
    if (params?.search && params.search.trim() !== '') {
      whereConditions.push({
        user: { fullName: { contains: params.search.trim() } },
      });
    }

    const where = whereConditions.length > 0 ? { AND: whereConditions } : {};

    const [data, total] = await Promise.all([
      this.prisma.student.findMany({
        where,
        include: this.include,
        orderBy: { user: { fullName: 'asc' } },
        skip,
        take: limit,
      }),
      this.prisma.student.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async findOne(id: number) {
    const s = await this.prisma.student.findUnique({
      where: { id },
      include: this.include,
    });
    if (!s) throw new NotFoundException('الطالب غير موجود');
    return s;
  }

  async create(dto: CreateStudentDto) {
    const phone =
      dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : undefined;

    if (dto.isAdult && !dto.password) {
      throw new BadRequestException('كلمة المرور مطلوبة للطالب البالغ');
    }

    try {
      const user = await this.prisma.user.create({
        data: {
          fullName: dto.fullName,
          phone,
          // A child student is a record, not an account: the role classifies
          // the row while the null hash keeps the login door shut. An adult
          // student is his own guardian, so his account is real.
          passwordHash: dto.isAdult
            ? await bcrypt.hash(dto.password!, 10)
            : null,
          role: dto.isAdult ? 'ADULT_STUDENT' : 'STUDENT',
          avatar: dto.avatar,
          student: {
            create: {
              birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
              address: dto.address,
              // An adult student has no parent by construction.
              parentId: dto.isAdult ? undefined : (dto.parentId ?? undefined),
              halaqaId: dto.halaqaId ?? undefined,
            },
          },
        },
        include: { student: true },
      });

      if (user.student) {
        return await this.findOne(user.student.id);
      }
      return user;
    } catch (error: any) {
      if (error?.code === 'P2002') {
        throw new ConflictException('رقم الهاتف مستخدم بالفعل');
      }
      throw error;
    }
  }

  async update(id: number, dto: UpdateStudentDto) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('الطالب غير موجود');

    const userUpdate: any = {};
    if (dto.fullName) userUpdate.fullName = dto.fullName;

    if (dto.phone !== undefined) {
      const phone =
        dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : null;
      if (phone !== null) {
        const existing = await this.prisma.user.findFirst({
          where: { phone, NOT: { id: student.userId } },
        });
        if (existing) {
          throw new ConflictException('رقم الهاتف مستخدم بالفعل');
        }
      }
      userUpdate.phone = phone;
    }

    if (dto.avatar) userUpdate.avatar = dto.avatar;

    const studentUpdate: any = {};
    if (dto.birthDate) studentUpdate.birthDate = new Date(dto.birthDate);
    if (dto.address !== undefined) studentUpdate.address = dto.address;
    if (dto.parentId !== undefined) studentUpdate.parentId = dto.parentId;
    if (dto.halaqaId !== undefined) studentUpdate.halaqaId = dto.halaqaId;
    // Compared against undefined, not truthiness: '' is how a teacher retracts
    // a rating, and a falsy check would silently drop that.
    if (dto.currentRating !== undefined)
      studentUpdate.currentRating = dto.currentRating;

    try {
      if (Object.keys(userUpdate).length > 0) {
        await this.prisma.user.update({
          where: { id: student.userId },
          data: userUpdate,
        });
      }
      return await this.prisma.student.update({
        where: { id },
        data: studentUpdate,
        include: this.include,
      });
    } catch (error: any) {
      if (error?.code === 'P2002') {
        throw new ConflictException('رقم الهاتف مستخدم بالفعل');
      }
      throw error;
    }
  }

  async getStudentProfile(id: number) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: {
        user: {
          select: { fullName: true, email: true, phone: true, avatar: true },
        },
        halaqa: {
          select: {
            name: true,
            level: true,
            teacher: { select: { user: { select: { fullName: true } } } },
          },
        },
        memorization: { orderBy: { recordedAt: 'desc' }, take: 10 },
        evaluations: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            teacher: { include: { user: { select: { fullName: true } } } },
          },
        },
        notes: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            teacher: { include: { user: { select: { fullName: true } } } },
          },
        },
        _count: { select: { attendance: true } },
      },
    });
    if (!student) throw new NotFoundException('الطالب غير موجود');

    // Arriving late is still arriving, so LATE counts towards the rate
    // alongside PRESENT — only an ABSENT day is held against the student.
    const attendedCount = await this.prisma.attendance.count({
      where: { studentId: id, status: { in: ['PRESENT', 'LATE'] } },
    });
    const totalAttendance = student._count.attendance;
    const attendanceRate =
      totalAttendance > 0
        ? Math.round((attendedCount / totalAttendance) * 100)
        : 0;

    return { ...student, attendanceRate };
  }

  async remove(id: number) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('الطالب غير موجود');
    // Hard delete — removing the user cascades to the student row and all of
    // its attendance, memorization, evaluations, notes and justifications.
    return this.prisma.user.delete({ where: { id: student.userId } });
  }
}
