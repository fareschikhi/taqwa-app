import { PrismaService } from '../../prisma/prisma.service';

/** Sentinel for "every halaqa", which only an admin gets. */
export const ALL_HALAQAS = 'ALL' as const;

export type HalaqaScope = number[] | typeof ALL_HALAQAS;

/** The shape of `request.user` this rule reads. */
export interface ScopedUser {
  role?: string;
  id?: number;
  teacher?: { id: number } | null;
  parent?: { id: number } | null;
  manager?: { id: number } | null;
}

/**
 * Which halaqas this user may see announcements for.
 *
 * The single scope rule for the feature. `HalaqaAccessGuard` reads it
 * forwards ("may this user reach halaqa X") and the `/mine` feed reads it
 * backwards ("which halaqas may this user reach"); sharing one function is
 * what stops a role added to one from being forgotten in the other.
 *
 * Unrecognised roles, and roles whose sub-record is missing, get `[]` — it
 * fails closed, like StudentOwnershipGuard's default branch.
 */
export async function halaqaIdsFor(
  prisma: PrismaService,
  user: ScopedUser | undefined,
): Promise<HalaqaScope> {
  if (!user) return [];

  switch (user.role) {
    case 'ADMIN':
      return ALL_HALAQAS;

    case 'MANAGER': {
      const managerId = user.manager?.id;
      if (!managerId) return [];
      const rows = await prisma.managerHalaqa.findMany({
        where: { managerId },
        select: { halaqaId: true },
      });
      return unique(rows.map((r) => r.halaqaId));
    }

    case 'TEACHER': {
      const teacherId = user.teacher?.id;
      if (!teacherId) return [];
      const rows = await prisma.halaqa.findMany({
        where: { teacherId },
        select: { id: true },
      });
      return unique(rows.map((r) => r.id));
    }

    case 'STUDENT':
    case 'ADULT_STUDENT': {
      if (!user.id) return [];
      // By userId, not by the student id on the token: a token carrying
      // someone else's student id must not reach their halaqa.
      const row = await prisma.student.findUnique({
        where: { userId: user.id },
        select: { halaqaId: true },
      });
      return row?.halaqaId == null ? [] : [row.halaqaId];
    }

    case 'PARENT': {
      const parentId = user.parent?.id;
      if (!parentId) return [];
      const rows = await prisma.student.findMany({
        where: { parentId },
        select: { halaqaId: true },
      });
      // Two children in one halaqa must not duplicate it, and a child not yet
      // placed in one contributes nothing.
      return unique(
        rows
          .map((r) => r.halaqaId)
          .filter((id): id is number => id != null),
      );
    }

    default:
      return [];
  }
}

const unique = (ids: number[]): number[] => [...new Set(ids)];
