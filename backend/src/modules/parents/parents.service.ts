import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateParentDto, UpdateParentDto } from './dto/parent.dto';
import * as bcrypt from 'bcrypt';
import { extraPhonesData } from '../../common/validators/account-fields';

@Injectable()
export class ParentsService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
    user: {
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        extraPhones: true,
        avatar: true,
        isActive: true,
        // Staff use these to find parents who never opened the app.
        lastLoginAt: true,
        lastSeenAt: true,
      },
    },
    students: {
      include: {
        user: { select: { id: true, fullName: true, avatar: true } },
        halaqa: { select: { id: true, name: true, level: true } },
        _count: { select: { attendance: true, memorization: true } },
      },
    },
  };

  async findAll() {
    return this.prisma.parent.findMany({
      include: this.include,
      orderBy: { user: { fullName: 'asc' } },
    });
  }

  async findOne(id: number) {
    const parent = await this.prisma.parent.findUnique({
      where: { id },
      include: this.include,
    });
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');
    return parent;
  }

  async findChildren(id: number) {
    const parent = await this.prisma.parent.findUnique({ where: { id } });
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');
    return this.prisma.student.findMany({
      where: { parentId: id },
      include: {
        user: { select: { id: true, fullName: true, avatar: true } },
        halaqa: { select: { id: true, name: true, level: true } },
        _count: { select: { attendance: true, memorization: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });
  }

  // Only a child student has a parent — an adult student holds his own
  // account — and every id must name a real student.
  private async assertChildStudents(studentIds: number[] | undefined) {
    if (!studentIds || studentIds.length === 0) return;

    const ids = [...new Set(studentIds)];
    const students = await this.prisma.student.findMany({
      where: { id: { in: ids } },
      select: { id: true, user: { select: { role: true } } },
    });

    if (students.length !== ids.length) {
      throw new BadRequestException('بعض الطلاب المختارين غير موجودين');
    }
    if (students.some((s) => s.user.role !== 'STUDENT')) {
      throw new BadRequestException('لا يمكن ربط طالب بالغ بولي أمر');
    }
  }

  async create(dto: CreateParentDto) {
    await this.assertChildStudents(dto.studentIds);
    const hash = await bcrypt.hash(dto.password, 10);
    const phone = dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : undefined;
    const email = dto.email && dto.email.trim() !== '' ? dto.email.trim() : undefined;

    return this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        email,
        phone,
        extraPhones: extraPhonesData(dto.extraPhones ?? [], phone),
        passwordHash: hash,
        mustChangePassword: true,
        role: 'PARENT',
        avatar: dto.avatar,
        parent: {
          create: {
            address: dto.address,
            students:
              dto.studentIds && dto.studentIds.length > 0
                ? { connect: dto.studentIds.map((id) => ({ id })) }
                : undefined,
          },
        },
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        extraPhones: true,
        avatar: true,
        isActive: true,
        createdAt: true,
        parent: true,
      },
    });
  }

  async update(id: number, dto: UpdateParentDto) {
    const parent = await this.prisma.parent.findUnique({ where: { id } });
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');
    await this.assertChildStudents(dto.studentIds);

    const userUpdate: any = {};
    if (dto.fullName) userUpdate.fullName = dto.fullName;
    if (dto.email !== undefined) {
      userUpdate.email = dto.email && dto.email.trim() !== '' ? dto.email.trim() : null;
    }
    if (dto.phone !== undefined) {
      userUpdate.phone = dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : null;
    }
    if (dto.extraPhones !== undefined) {
      userUpdate.extraPhones = extraPhonesData(dto.extraPhones, dto.phone);
    }
    if (dto.avatar) userUpdate.avatar = dto.avatar;
    if (dto.password) {
      userUpdate.passwordHash = await bcrypt.hash(dto.password, 10);
      userUpdate.mustChangePassword = true;
    }

    const parentUpdate: any = {};
    if (dto.address !== undefined) parentUpdate.address = dto.address;
    // `set` unlinks every child left out of the list (parentId -> null).
    if (dto.studentIds !== undefined) {
      parentUpdate.students = { set: dto.studentIds.map((id) => ({ id })) };
    }

    if (Object.keys(userUpdate).length > 0) {
      await this.prisma.user.update({
        where: { id: parent.userId },
        data: userUpdate,
      });
    }

    return this.prisma.parent.update({
      where: { id },
      data: parentUpdate,
      include: this.include,
    });
  }

  async remove(id: number) {
    const parent = await this.prisma.parent.findUnique({ where: { id } });
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');
    // Hard delete — removing the user cascades to the parent row. Children are
    // kept: students.parentId is ON DELETE SET NULL.
    return this.prisma.user.delete({ where: { id: parent.userId } });
  }
}
