import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateParentDto, UpdateParentDto } from './dto/parent.dto';
import * as bcrypt from 'bcrypt';

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
        avatar: true,
        isActive: true,
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

  async create(dto: CreateParentDto) {
    const hash = await bcrypt.hash(dto.password, 10);
    const phone = dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : undefined;
    const email = dto.email && dto.email.trim() !== '' ? dto.email.trim() : undefined;

    return this.prisma.user.create({
      data: {
        fullName: dto.fullName,
        email,
        phone,
        passwordHash: hash,
        role: 'PARENT',
        avatar: dto.avatar,
        parent: {
          create: {
            address: dto.address,
          },
        },
      },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
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

    const userUpdate: any = {};
    if (dto.fullName) userUpdate.fullName = dto.fullName;
    if (dto.email !== undefined) {
      userUpdate.email = dto.email && dto.email.trim() !== '' ? dto.email.trim() : null;
    }
    if (dto.phone !== undefined) {
      userUpdate.phone = dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : null;
    }
    if (dto.avatar) userUpdate.avatar = dto.avatar;
    if (dto.password)
      userUpdate.passwordHash = await bcrypt.hash(dto.password, 10);

    const parentUpdate: any = {};
    if (dto.address !== undefined) parentUpdate.address = dto.address;

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
    return this.prisma.user.update({
      where: { id: parent.userId },
      data: { isActive: false },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        avatar: true,
        isActive: true,
        createdAt: true,
      },
    });
  }
}
