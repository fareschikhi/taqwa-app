import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PointSource, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ALL_HALAQAS, halaqaIdsFor } from '../../common/guards/halaqa-scope';
import { CreatePointsDto } from './dto/points.dto';
import { PointsActor, canAdjustUser, canViewStudent } from './points-access';

export type PointsSummary = {
  total: string;
  entries: Array<{
    id: number;
    source: PointSource;
    amount: string;
    date: Date | null;
    reason: string | null;
    createdAt: Date;
    createdBy: { fullName: string } | null;
  }>;
};

// Amounts leave the server as exact decimal strings ("0.125", "-1"): a JSON
// number would hand the app a float, and the total is summed by the database
// for the same reason.
const asText = (amount: Prisma.Decimal | null | undefined) =>
  amount == null ? '0' : amount.toString();

@Injectable()
export class PointsService {
  constructor(private prisma: PrismaService) {}

  async summaryForUser(userId: number): Promise<PointsSummary> {
    const [entries, sum] = await Promise.all([
      this.prisma.pointEntry.findMany({
        where: { userId },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        select: {
          id: true,
          source: true,
          amount: true,
          date: true,
          reason: true,
          createdAt: true,
          createdBy: { select: { fullName: true } },
        },
      }),
      this.prisma.pointEntry.aggregate({
        where: { userId },
        _sum: { amount: true },
      }),
    ]);
    return {
      total: asText(sum._sum.amount),
      entries: entries.map((e) => ({ ...e, amount: asText(e.amount) })),
    };
  }

  async summaryForStudent(
    studentId: number,
    actor: PointsActor,
  ): Promise<PointsSummary> {
    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { userId: true },
    });
    if (!student) throw new NotFoundException('الطالب غير موجود');
    if (!(await canViewStudent(this.prisma, actor, studentId))) {
      throw new ForbiddenException('لا يمكنك الاطلاع على نقاط هذا الطالب');
    }
    return this.summaryForUser(student.userId);
  }

  async halaqaTotals(halaqaId: number, actor: PointsActor) {
    // Only admins and the halaqa's own staff reach here (the controller's
    // roles), so the shared scope rule answers exactly the right question.
    const scope = await halaqaIdsFor(this.prisma, actor);
    if (scope !== ALL_HALAQAS && !scope.includes(halaqaId)) {
      throw new ForbiddenException('لا يمكنك الاطلاع على نقاط هذه الحلقة');
    }

    const students = await this.prisma.student.findMany({
      where: { halaqaId },
      select: {
        id: true,
        userId: true,
        user: { select: { fullName: true, avatar: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });
    // One grouped query for the whole halaqa, not one per student.
    const sums = await this.prisma.pointEntry.groupBy({
      by: ['userId'],
      where: { userId: { in: students.map((s) => s.userId) } },
      _sum: { amount: true },
    });
    const totals = new Map(sums.map((s) => [s.userId, s._sum.amount]));

    return students.map((s) => ({
      studentId: s.id,
      userId: s.userId,
      fullName: s.user.fullName,
      avatar: s.user.avatar,
      total: asText(totals.get(s.userId)),
    }));
  }

  async create(dto: CreatePointsDto, actor: PointsActor) {
    await this.assertCanAdjust(dto.userId, actor);
    return this.prisma.pointEntry.create({
      data: {
        userId: dto.userId,
        amount: new Prisma.Decimal(dto.amount).toFixed(3),
        source: 'MANUAL',
        date: null,
        // A blank reason says nothing, so it is stored as no reason at all.
        reason: dto.reason?.trim() || null,
        createdById: actor.id,
      },
    });
  }

  async remove(id: number, actor: PointsActor) {
    const entry = await this.prisma.pointEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('القيد غير موجود');

    // An automatic entry belongs to its attendance or recitation: deleting it
    // here would only last until the next save of that day.
    if (entry.source !== 'MANUAL') {
      throw new BadRequestException(
        'لا يمكن حذف نقاط تلقائية، عدّل الحضور أو التسميع بدلاً من ذلك',
      );
    }

    if (actor.role !== 'ADMIN') {
      // Staff undo their own adjustments only, and only while the student is
      // still theirs: a teacher whose student moved on cannot reach back.
      if (entry.createdById !== actor.id) {
        throw new ForbiddenException('لا يمكنك حذف تعديل أجراه غيرك');
      }
      await this.assertCanAdjust(entry.userId, actor);
    }

    return this.prisma.pointEntry.delete({ where: { id } });
  }

  private async assertCanAdjust(userId: number, actor: PointsActor) {
    switch (await canAdjustUser(this.prisma, actor, userId)) {
      case 'ok':
        return;
      case 'not-found':
        throw new NotFoundException('الحساب غير موجود');
      case 'not-eligible':
        throw new BadRequestException('هذا الحساب لا يملك نقاطاً');
      default:
        throw new ForbiddenException('لا يمكنك تعديل نقاط هذا الحساب');
    }
  }
}
