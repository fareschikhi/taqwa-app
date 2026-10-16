import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateUserDto, UpdateMeDto, UpdateUserDto } from './dto/user.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.user.findMany({
      where: { isActive: true },
      select: { id: true, fullName: true, email: true, phone: true, role: true, avatar: true, createdAt: true },
      orderBy: { createdAt: 'desc' },
    });
  }

  async findOne(id: number) {
    const user = await this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        avatar: true,
        isActive: true,
        createdAt: true,
        student: { select: { id: true } },
        parent: { select: { id: true } },
        teacher: { select: { id: true } },
        manager: {
          select: {
            id: true,
            canManageAccounts: true,
            canDeleteAccounts: true,
          },
        },
      },
    });
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return user;
  }

  async create(dto: CreateUserDto) {
    const hash = await bcrypt.hash(dto.password, 10);
    return this.prisma.user.create({
      data: {
        ...dto,
        passwordHash: hash,
        password: undefined,
        // An admin-set password is temporary, except on an admin account:
        // admins manage their own.
        mustChangePassword: dto.role !== 'ADMIN',
      } as any,
      select: { id: true, fullName: true, email: true, role: true, createdAt: true },
    });
  }

  /// A user editing their own account. Phone and email are unique columns and
  /// phone is the login identifier, so a value already held by somebody else
  /// is refused before anything is written.
  async updateMe(userId: number, dto: UpdateMeDto) {
    const data: {
      fullName?: string;
      phone?: string | null;
      email?: string | null;
    } = {};

    if (dto.fullName !== undefined) data.fullName = dto.fullName.trim();

    for (const field of ['phone', 'email'] as const) {
      const raw = dto[field];
      if (raw === undefined) continue;

      const value = raw.trim();
      if (value === '') {
        // Nothing to collide with, so no lookup.
        data[field] = null;
        continue;
      }

      const taken = await this.prisma.user.findFirst({
        where: { [field]: value, NOT: { id: userId } },
        select: { id: true },
      });
      if (taken) {
        throw new ConflictException(
          field === 'phone'
            ? 'رقم الهاتف مستخدم بالفعل'
            : 'البريد الإلكتروني مستخدم بالفعل',
        );
      }
      data[field] = value;
    }

    await this.prisma.user.update({ where: { id: userId }, data });
    return this.findOne(userId);
  }

  async update(id: number, dto: UpdateUserDto) {
    const data: any = { ...dto };
    if (dto.password) {
      data.passwordHash = await bcrypt.hash(dto.password, 10);
      delete data.password;
      // Temporary unless it is an admin's: admins manage their own.
      const target = await this.prisma.user.findUnique({
        where: { id },
        select: { role: true },
      });
      data.mustChangePassword = target?.role !== 'ADMIN';
    }
    return this.prisma.user.update({ where: { id }, data });
  }

  async remove(id: number) {
    return this.prisma.user.update({ where: { id }, data: { isActive: false } });
  }

  async getStats() {
    const [totalStudents, totalTeachers, totalHalaqas, attendanceToday] = await Promise.all([
      this.prisma.student.count(),
      this.prisma.teacher.count(),
      this.prisma.halaqa.count(),
      // Late arrivals count as attendance, not against it.
      this.prisma.attendance.count({
        where: {
          date: new Date(new Date().setHours(0, 0, 0, 0)),
          status: { in: ['PRESENT', 'LATE'] },
        },
      }),
    ]);

    const totalAttendanceToday = await this.prisma.attendance.count({
      where: { date: new Date(new Date().setHours(0, 0, 0, 0)) },
    });

    return {
      totalStudents,
      totalTeachers,
      totalHalaqas,
      attendanceRate: totalAttendanceToday > 0
        ? Math.round((attendanceToday / totalAttendanceToday) * 100)
        : 0,
    };
  }
}
