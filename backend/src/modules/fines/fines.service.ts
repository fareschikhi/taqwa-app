import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateFineDto } from './dto/fine.dto';

/// Who is making the adjustment. Carries the teacher id because the halaqa a
/// student sits in is what decides whether a given teacher may charge him.
export type FineActor = {
  id: number;
  role: string;
  teacher?: { id: number } | null;
};

@Injectable()
export class FinesService {
  constructor(private prisma: PrismaService) {}

  /// Refuses a teacher who does not run the halaqa this student sits in.
  ///
  /// Reads are deliberately looser — StudentOwnershipGuard lets any teacher
  /// see any student, and that is the established rule. Writes that move money
  /// are where it stops being good enough. Admins and managers are unrestricted
  /// because oversight is their job.
  private async assertCanAdjust(studentId: number, actor: FineActor) {
    if (actor.role !== 'TEACHER') return;

    const student = await this.prisma.student.findUnique({
      where: { id: studentId },
      select: { halaqa: { select: { teacherId: true } } },
    });

    // Each side is checked on its own rather than compared directly: two
    // missing values (a teacher-role actor with no teacher profile, a student
    // with no halaqa) must not cancel out into a pass. A missing teacher
    // profile is a malformed actor and a halaqa-less student has no owning
    // teacher, so either absence alone is grounds to refuse.
    const teacherId = actor.teacher?.id;
    const owningTeacherId = student?.halaqa?.teacherId;
    if (
      teacherId == null ||
      owningTeacherId == null ||
      teacherId !== owningTeacherId
    ) {
      throw new ForbiddenException('لا يمكنك تعديل رسوم طالب من حلقة أخرى');
    }
  }

  /// Charges minus reductions, floored at zero.
  ///
  /// Computed rather than stored: a cached total drifts the first time a write
  /// path forgets it, and the ledger is short enough per student that summing
  /// it costs nothing.
  private balanceOf(
    entries: Array<{ kind: string; amount: number }>,
  ): number {
    const raw = entries.reduce(
      (sum, e) => sum + (e.kind === 'CHARGE' ? e.amount : -e.amount),
      0,
    );
    // A withdrawn charge sitting under an existing reduction can drive the sum
    // below zero. Nobody owes a negative amount.
    return raw < 0 ? 0 : raw;
  }

  async findByStudent(studentId: number) {
    const entries = await this.prisma.fineEntry.findMany({
      where: { studentId },
      orderBy: { createdAt: 'desc' },
    });
    return { balance: this.balanceOf(entries), entries };
  }

  async findByHalaqa(halaqaId: number) {
    const students = await this.prisma.student.findMany({
      where: { halaqaId },
      select: {
        id: true,
        user: { select: { fullName: true, avatar: true } },
        fines: { select: { kind: true, amount: true } },
      },
      orderBy: { user: { fullName: 'asc' } },
    });

    return students.map((s) => ({
      studentId: s.id,
      fullName: s.user.fullName,
      avatar: s.user.avatar,
      balance: this.balanceOf(s.fines),
    }));
  }

  async create(dto: CreateFineDto, actor: FineActor) {
    await this.assertCanAdjust(dto.studentId, actor);

    if (dto.kind === 'REDUCTION') {
      const { balance } = await this.findByStudent(dto.studentId);
      // Rejected rather than clamped: a teacher who typed 500 instead of 50
      // should be told, not quietly obeyed.
      if (dto.amount > balance) {
        throw new BadRequestException(
          'قيمة الخصم أكبر من الرصيد المستحق',
        );
      }
    }

    return this.prisma.fineEntry.create({
      data: {
        studentId: dto.studentId,
        kind: dto.kind,
        amount: dto.amount,
        reason: dto.reason ?? null,
        source: 'MANUAL',
        date: null,
        createdById: actor.id,
      },
    });
  }

  async remove(id: number, actor: FineActor) {
    const entry = await this.prisma.fineEntry.findUnique({ where: { id } });
    if (!entry) throw new NotFoundException('القيد غير موجود');

    await this.assertCanAdjust(entry.studentId, actor);

    // An auto-charge belongs to its attendance row: correcting the attendance
    // is what withdraws it, and deleting it here would only last until the
    // next save of that day.
    if (entry.source !== 'MANUAL') {
      throw new BadRequestException(
        'لا يمكن حذف قيد تلقائي، عدّل الحضور بدلاً من ذلك',
      );
    }

    return this.prisma.fineEntry.delete({ where: { id } });
  }
}
