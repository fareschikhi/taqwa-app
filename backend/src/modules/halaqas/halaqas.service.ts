import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateHalaqaDto, UpdateHalaqaDto } from './dto/halaqa.dto';

@Injectable()
export class HalaqasService {
  constructor(private prisma: PrismaService) {}

  async findAll() {
    return this.prisma.halaqa.findMany({
      include: {
        teacher: {
          include: { user: { select: { fullName: true, avatar: true } } },
        },
        _count: { select: { students: true } },
      },
      orderBy: { name: 'asc' },
    });
  }

  async findOne(id: number) {
    const halaqa = await this.prisma.halaqa.findUnique({
      where: { id },
      include: {
        teacher: {
          include: {
            user: { select: { id: true, fullName: true, avatar: true } },
          },
        },
        students: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                avatar: true,
                phone: true,
              },
            },
          },
        },
      },
    });
    if (!halaqa) throw new NotFoundException('الحلقة غير موجودة');
    return halaqa;
  }

  async create(dto: CreateHalaqaDto) {
    const { studentIds, ...halaqaData } = dto;
    return this.prisma.halaqa.create({
      data: {
        ...halaqaData,
        students:
          studentIds && studentIds.length > 0
            ? { connect: studentIds.map((id) => ({ id })) }
            : undefined,
      },
      include: {
        teacher: { include: { user: { select: { fullName: true } } } },
      },
    });
  }

  async update(id: number, dto: UpdateHalaqaDto) {
    const halaqa = await this.prisma.halaqa.findUnique({ where: { id } });
    if (!halaqa) throw new NotFoundException('الحلقة غير موجودة');

    const { studentIds, ...halaqaData } = dto;

    return this.prisma.halaqa.update({
      where: { id },
      data: {
        ...halaqaData,
        // `set` disconnects every student currently on this halaqa and
        // reconnects exactly the given list — the correct way to fully
        // replace a to-many relation from the "one" side.
        students:
          studentIds !== undefined
            ? { set: studentIds.map((sid) => ({ id: sid })) }
            : undefined,
      },
      include: {
        teacher: { include: { user: { select: { fullName: true } } } },
        students: {
          include: {
            user: { select: { fullName: true, avatar: true } },
          },
        },
      },
    });
  }

  async remove(id: number) {
    const halaqa = await this.prisma.halaqa.findUnique({ where: { id } });
    if (!halaqa) throw new NotFoundException('الحلقة غير موجودة');
    return this.prisma.halaqa.delete({ where: { id } });
  }
}
