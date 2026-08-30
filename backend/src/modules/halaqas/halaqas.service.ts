import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
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

  // An adults' halaqa charges fines; a child's does not. Enforcing the pairing
  // once, here, is what lets every screen downstream trust `isAdult` alone
  // rather than re-checking each student's role.
  private async assertEnrolmentMatches(
    isAdult: boolean,
    studentIds: number[] | undefined,
  ) {
    if (!studentIds || studentIds.length === 0) return;

    const students = await this.prisma.student.findMany({
      where: { id: { in: studentIds } },
      select: { id: true, user: { select: { role: true } } },
    });

    const wanted = isAdult ? 'ADULT_STUDENT' : 'STUDENT';
    const mismatched = students.filter((s) => s.user.role !== wanted);
    if (mismatched.length > 0) {
      throw new BadRequestException(
        isAdult
          ? 'حلقة الكبار تقبل الطلاب البالغين فقط'
          : 'لا يمكن إضافة طالب بالغ إلى حلقة عادية',
      );
    }
  }

  async create(dto: CreateHalaqaDto) {
    const { studentIds, ...halaqaData } = dto;
    await this.assertEnrolmentMatches(dto.isAdult ?? false, studentIds);
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
    const nextIsAdult = dto.isAdult ?? halaqa.isAdult;

    // `assertEnrolmentMatches` only checks the roster it is handed, and it is
    // handed nothing whenever the edit form omits `studentIds` (which it
    // always does — the update endpoint replaces the whole roster, so a
    // partial list would disconnect everyone the admin did not re-pick).
    // That is fine when the halaqa's type isn't changing. But if `isAdult`
    // IS flipping and no new roster was sent, the *existing* roster is about
    // to become mismatched with nobody having ever checked it — so load who
    // is currently connected and validate that roster against the new type
    // instead of silently trusting it.
    let idsToValidate = studentIds;
    if (
      studentIds === undefined &&
      dto.isAdult !== undefined &&
      dto.isAdult !== halaqa.isAdult
    ) {
      const currentRoster = await this.prisma.student.findMany({
        where: { halaqaId: id },
        select: { id: true },
      });
      idsToValidate = currentRoster.map((s) => s.id);
    }

    await this.assertEnrolmentMatches(nextIsAdult, idsToValidate);

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
