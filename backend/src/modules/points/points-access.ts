import { PrismaService } from '../../prisma/prisma.service';
import { ALL_HALAQAS, halaqaIdsFor } from '../../common/guards/halaqa-scope';

/// The parts of `request.user` the points rules read.
export type PointsActor = {
  id: number;
  role: string;
  teacher?: { id: number } | null;
  manager?: { id: number } | null;
  parent?: { id: number } | null;
};

export type AdjustAnswer = 'ok' | 'forbidden' | 'not-found' | 'not-eligible';

const STAFF = new Set(['TEACHER', 'MANAGER']);
const STUDENTS = new Set(['STUDENT', 'ADULT_STUDENT']);
// The accounts that carry points. Admins hand them out; parents watch their
// children's.
const HAS_POINTS = new Set([...STUDENTS, ...STAFF]);

/// Whether a teacher or manager reaches this halaqa.
///
/// Called for staff only: `halaqaIdsFor` also answers for parents and
/// students (their children's or own halaqa), and through that a parent would
/// see a classmate's points. A student with no halaqa belongs to no one's
/// halaqa, so `canAccessUnassigned` does not reach points — the rule is
/// "same halaqa".
async function staffReaches(
  prisma: PrismaService,
  actor: PointsActor,
  halaqaId: number | null,
): Promise<boolean> {
  if (halaqaId == null) return false;
  const scope = await halaqaIdsFor(prisma, actor);
  return scope === ALL_HALAQAS || scope.includes(halaqaId);
}

/// Who may read a student's points. Stricter on purpose than
/// StudentOwnershipGuard, which lets any teacher read any student: points are
/// personal, so staff see only their own halaqas.
export async function canViewStudent(
  prisma: PrismaService,
  actor: PointsActor,
  studentId: number,
): Promise<boolean> {
  const student = await prisma.student.findUnique({
    where: { id: studentId },
    select: { userId: true, parentId: true, halaqaId: true },
  });
  if (!student) return false;

  switch (actor.role) {
    case 'ADMIN':
      return true;
    case 'PARENT':
      return actor.parent?.id != null && student.parentId === actor.parent.id;
    case 'ADULT_STUDENT':
      return student.userId === actor.id;
    case 'TEACHER':
    case 'MANAGER':
      return staffReaches(prisma, actor, student.halaqaId);
    default:
      return false;
  }
}

/// Who may add or take away points from a user's account.
///
/// Admin: any account that has points. Teachers and managers: students in
/// their own halaqas only — never another staff member.
export async function canAdjustUser(
  prisma: PrismaService,
  actor: PointsActor,
  userId: number,
): Promise<AdjustAnswer> {
  const target = await prisma.user.findUnique({
    where: { id: userId },
    select: { role: true, student: { select: { halaqaId: true } } },
  });
  if (!target) return 'not-found';
  if (!HAS_POINTS.has(target.role)) return 'not-eligible';

  if (actor.role === 'ADMIN') return 'ok';
  if (!STAFF.has(actor.role) || !STUDENTS.has(target.role)) return 'forbidden';

  return (await staffReaches(prisma, actor, target.student?.halaqaId ?? null))
    ? 'ok'
    : 'forbidden';
}
