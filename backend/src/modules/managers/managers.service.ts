import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateManagerDto,
  UpdateManagerDto,
  UpdateManagerStatusDto,
} from './dto/manager.dto';
import * as bcrypt from 'bcrypt';

@Injectable()
export class ManagersService {
  constructor(private prisma: PrismaService) {}

  private readonly userSelect = {
    id: true,
    fullName: true,
    email: true,
    phone: true,
    avatar: true,
    isActive: true,
    createdAt: true,
  };

  async findAll() {
    return this.prisma.manager.findMany({
      include: {
        user: { select: this.userSelect },
        halaqas: {
          include: {
            halaqa: { select: { id: true, name: true, level: true } },
          },
        },
        _count: { select: { justifications: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });
  }

  async findOne(id: number) {
    const m = await this.prisma.manager.findUnique({
      where: { id },
      include: {
        user: { select: this.userSelect },
        halaqas: {
          include: {
            halaqa: {
              select: { id: true, name: true, level: true, description: true },
            },
          },
        },
        _count: { select: { justifications: true } },
      },
    });
    if (!m) throw new NotFoundException('المدير غير موجود');
    return m;
  }

  async create(dto: CreateManagerDto) {
    const hash = await bcrypt.hash(dto.password, 10);
    const { password, halaqaIds, canManageAccounts, canDeleteAccounts, ...rest } =
      dto;

    const phone =
      rest.phone && rest.phone.trim() !== '' ? rest.phone.trim() : undefined;
    const email =
      rest.email && rest.email.trim() !== '' ? rest.email.trim() : undefined;

    const user = await this.prisma.user.create({
      data: {
        fullName: rest.fullName,
        email,
        phone,
        passwordHash: hash,
        role: 'MANAGER',
        avatar: rest.avatar,
        manager: {
          create: {
            canManageAccounts: canManageAccounts ?? false,
            canDeleteAccounts: canDeleteAccounts ?? false,
            ...(halaqaIds && halaqaIds.length > 0
              ? {
                  halaqas: {
                    create: halaqaIds.map((halaqaId) => ({ halaqaId })),
                  },
                }
              : {}),
          },
        },
      },
      include: {
        manager: {
          include: {
            halaqas: {
              include: { halaqa: { select: { id: true, name: true } } },
            },
          },
        },
      },
    });
    return user;
  }

  async update(id: number, dto: UpdateManagerDto) {
    const manager = await this.prisma.manager.findUnique({ where: { id } });
    if (!manager) throw new NotFoundException('المدير غير موجود');

    const { password, halaqaIds, canManageAccounts, canDeleteAccounts, ...rest } =
      dto;
    const userUpdate: any = { ...rest };
    if (password) userUpdate.passwordHash = await bcrypt.hash(password, 10);

    await this.prisma.user.update({
      where: { id: manager.userId },
      data: userUpdate,
    });

    if (canManageAccounts !== undefined || canDeleteAccounts !== undefined) {
      await this.prisma.manager.update({
        where: { id },
        data: {
          ...(canManageAccounts !== undefined ? { canManageAccounts } : {}),
          ...(canDeleteAccounts !== undefined ? { canDeleteAccounts } : {}),
        },
      });
    }

    if (halaqaIds !== undefined) {
      await this.prisma.managerHalaqa.deleteMany({ where: { managerId: id } });
      if (halaqaIds.length > 0) {
        await this.prisma.managerHalaqa.createMany({
          data: halaqaIds.map((halaqaId) => ({ managerId: id, halaqaId })),
        });
      }
    }

    return this.findOne(id);
  }

  async updateStatus(id: number, dto: UpdateManagerStatusDto) {
    const manager = await this.prisma.manager.findUnique({ where: { id } });
    if (!manager) throw new NotFoundException('المدير غير موجود');

    await this.prisma.user.update({
      where: { id: manager.userId },
      data: { isActive: dto.isActive },
    });

    return this.findOne(id);
  }

  async remove(id: number) {
    const manager = await this.prisma.manager.findUnique({ where: { id } });
    if (!manager) throw new NotFoundException('المدير غير موجود');
    // Soft delete — deactivate user
    return this.prisma.user.update({
      where: { id: manager.userId },
      data: { isActive: false },
    });
  }

  async getStudents(id: number) {
    const manager = await this.prisma.manager.findUnique({
      where: { id },
      include: { halaqas: { select: { halaqaId: true } } },
    });
    if (!manager) throw new NotFoundException('المدير غير موجود');

    const halaqaIds = manager.halaqas.map((h) => h.halaqaId);

    return this.prisma.student.findMany({
      where: {
        halaqaId: { in: halaqaIds },
      },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            avatar: true,
            isActive: true,
          },
        },
        halaqa: { select: { id: true, name: true } },
        _count: { select: { attendance: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });
  }

  async getHalaqas(id: number) {
    const manager = await this.prisma.manager.findUnique({
      where: { id },
      include: {
        halaqas: {
          include: {
            halaqa: {
              include: {
                teacher: {
                  include: {
                    user: { select: { fullName: true, avatar: true } },
                  },
                },
                _count: { select: { students: true } },
              },
            },
          },
        },
      },
    });
    if (!manager) throw new NotFoundException('المدير غير موجود');
    return manager.halaqas.map((mh) => mh.halaqa);
  }
}
