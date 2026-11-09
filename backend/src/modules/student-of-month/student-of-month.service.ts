import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { ALL_HALAQAS, halaqaIdsFor } from '../../common/guards/halaqa-scope';
import type { PointsActor } from '../points/points-access';
import { milliToAmount } from '../points/points-rules';
import {
  MonthWindow,
  RankedCandidate,
  judgedMonth,
  rankCandidates,
} from './student-of-month-rules';

export type Candidate = {
  studentId: number;
  fullName: string;
  avatar: string | null;
  /// Exact decimal strings, as the points endpoints send them.
  points: string;
  finesPenalty: number;
  score: string;
  isTop: boolean;
};

export type PendingPick = {
  halaqaId: number;
  halaqaName: string;
  month: string;
  candidates: Candidate[];
};

export type ShownPick = {
  halaqaId: number;
  halaqaName: string;
  month: string;
  student: { id: number; fullName: string; avatar: string | null };
};

const toMilli = (d: Prisma.Decimal | null | undefined) =>
  d == null ? 0 : new Prisma.Decimal(d).mul(1000).toNumber();

@Injectable()
export class StudentOfMonthService {
  constructor(private prisma: PrismaService) {}

  /// The teacher's halaqas still waiting for a pick for the month that just
  /// ended. Empty once every one is validated — that is what stops the popup.
  async pending(actor: PointsActor, now = new Date()): Promise<PendingPick[]> {
    const window = judgedMonth(now);
    const teacherId = actor.teacher?.id;
    if (!window || teacherId == null) return [];

    const halaqas = await this.prisma.halaqa.findMany({
      where: {
        teacherId,
        studentsOfMonth: { none: { month: window.month } },
      },
      select: { id: true, name: true },
      orderBy: { id: 'asc' },
    });

    const result: PendingPick[] = [];
    for (const halaqa of halaqas) {
      const candidates = await this.candidates(halaqa.id, window);
      // A halaqa with no students has no one to choose; asking would only
      // trap the teacher in a popup they cannot close.
      if (candidates.length === 0) continue;
      result.push({
        halaqaId: halaqa.id,
        halaqaName: halaqa.name,
        month: window.month,
        candidates,
      });
    }
    return result;
  }

  /// Validates the teacher's pick. Any student of the halaqa may be chosen;
  /// whether he was the top scorer is recorded, not enforced.
  async select(
    actor: PointsActor,
    dto: { halaqaId: number; studentId: number },
    now = new Date(),
  ) {
    const window = judgedMonth(now);
    if (!window) {
      throw new BadRequestException('لا يوجد شهر مكتمل لاختيار طالبه بعد');
    }

    const halaqa = await this.prisma.halaqa.findUnique({
      where: { id: dto.halaqaId },
      select: { teacherId: true },
    });
    if (!halaqa) throw new NotFoundException('الحلقة غير موجودة');
    if (actor.teacher?.id == null || halaqa.teacherId !== actor.teacher.id) {
      throw new ForbiddenException('يختار طالب الشهر معلم الحلقة فقط');
    }

    const candidates = await this.candidates(dto.halaqaId, window);
    const chosen = candidates.find((c) => c.studentId === dto.studentId);
    if (!chosen) {
      throw new BadRequestException('هذا الطالب ليس من طلاب الحلقة');
    }

    const existing = await this.prisma.studentOfMonth.findUnique({
      where: {
        halaqaId_month: { halaqaId: dto.halaqaId, month: window.month },
      },
      select: { id: true },
    });
    if (existing) {
      throw new ConflictException('تم اختيار طالب هذا الشهر مسبقاً');
    }

    try {
      return await this.prisma.studentOfMonth.create({
        data: {
          halaqaId: dto.halaqaId,
          month: window.month,
          studentId: dto.studentId,
          score: chosen.score,
          wasTopScorer: chosen.isTop,
          selectedById: actor.id,
        },
      });
    } catch (e) {
      // Two devices validating at once: the unique index lets one through.
      if (
        e instanceof Prisma.PrismaClientKnownRequestError &&
        e.code === 'P2002'
      ) {
        throw new ConflictException('تم اختيار طالب هذا الشهر مسبقاً');
      }
      throw e;
    }
  }

  /// The validated picks the caller's dashboard shows, one per halaqa they
  /// reach (their own, their children's, or the ones they teach or manage).
  /// A halaqa whose teacher has not validated yet has no entry: no card.
  async shown(actor: PointsActor, now = new Date()): Promise<ShownPick[]> {
    const window = judgedMonth(now);
    if (!window) return [];

    const scope = await halaqaIdsFor(this.prisma, actor);
    if (scope !== ALL_HALAQAS && scope.length === 0) return [];

    const rows = await this.prisma.studentOfMonth.findMany({
      where: {
        month: window.month,
        ...(scope === ALL_HALAQAS ? {} : { halaqaId: { in: scope } }),
      },
      select: {
        halaqaId: true,
        month: true,
        halaqa: { select: { name: true } },
        student: {
          select: {
            id: true,
            user: { select: { fullName: true, avatar: true } },
          },
        },
      },
      orderBy: { halaqaId: 'asc' },
    });

    // The score stays off on purpose: classmates and their parents see who
    // was chosen, never anyone else's points.
    return rows.map((r) => ({
      halaqaId: r.halaqaId,
      halaqaName: r.halaqa.name,
      month: r.month,
      student: {
        id: r.student.id,
        fullName: r.student.user.fullName,
        avatar: r.student.user.avatar,
      },
    }));
  }

  /// Every active student of the halaqa with the month's figures, ranked.
  private async candidates(
    halaqaId: number,
    window: MonthWindow,
  ): Promise<Candidate[]> {
    const students = await this.prisma.student.findMany({
      where: {
        halaqaId,
        user: { isActive: true, role: { in: ['STUDENT', 'ADULT_STUDENT'] } },
      },
      select: {
        id: true,
        userId: true,
        user: { select: { fullName: true, avatar: true } },
      },
    });
    if (students.length === 0) return [];

    // Dated rows count by their day; manual rows (no date) by when they were
    // made. One grouped query each for the whole halaqa.
    const inMonth = {
      OR: [
        { date: { gte: window.dayFrom, lt: window.dayTo } },
        {
          date: null,
          createdAt: { gte: window.instantFrom, lt: window.instantTo },
        },
      ],
    };

    const [pointSums, fineSums] = await Promise.all([
      this.prisma.pointEntry.groupBy({
        by: ['userId'],
        where: { userId: { in: students.map((s) => s.userId) }, ...inMonth },
        _sum: { amount: true },
      }),
      this.prisma.fineEntry.groupBy({
        by: ['studentId', 'kind'],
        where: { studentId: { in: students.map((s) => s.id) }, ...inMonth },
        _sum: { amount: true },
      }),
    ]);

    const points = new Map(
      pointSums.map((p) => [p.userId, toMilli(p._sum.amount)]),
    );
    const fines = new Map<number, number>();
    for (const f of fineSums) {
      const signed = (f._sum.amount ?? 0) * (f.kind === 'REDUCTION' ? -1 : 1);
      fines.set(f.studentId, (fines.get(f.studentId) ?? 0) + signed);
    }

    const ranked = rankCandidates(
      students.map((s) => ({
        studentId: s.id,
        pointsMilli: points.get(s.userId) ?? 0,
        netFines: fines.get(s.id) ?? 0,
      })),
    );
    const byId = new Map(students.map((s) => [s.id, s]));
    return ranked.map((r: RankedCandidate) => {
      const s = byId.get(r.studentId)!;
      return {
        studentId: r.studentId,
        fullName: s.user.fullName,
        avatar: s.user.avatar,
        points: milliToAmount(r.pointsMilli),
        finesPenalty: r.finesPenalty,
        score: milliToAmount(r.scoreMilli),
        isTop: r.isTop,
      };
    });
  }
}
