import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateUserDto, UpdateUserDto } from './dto/user.dto';
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
      },
    });
    if (!user) throw new NotFoundException('المستخدم غير موجود');
    return user;
  }

  async create(dto: CreateUserDto) {
    const hash = await bcrypt.hash(dto.password, 10);
    return this.prisma.user.create({
      data: { ...dto, passwordHash: hash, password: undefined } as any,
      select: { id: true, fullName: true, email: true, role: true, createdAt: true },
    });
  }

  async update(id: number, dto: UpdateUserDto) {
    const data: any = { ...dto };
    if (dto.password) {
      data.passwordHash = await bcrypt.hash(dto.password, 10);
      delete data.password;
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
      this.prisma.attendance.count({
        where: {
          date: new Date(new Date().setHours(0, 0, 0, 0)),
          status: 'PRESENT',
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
