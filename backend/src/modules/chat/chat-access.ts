import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { halaqaIdsFor, ScopedUser } from '../../common/guards/halaqa-scope';

/** The shape of `request.user` the chat rule reads (see JwtStrategy). */
export type ChatUser = ScopedUser & {
  id: number;
  manager?: {
    id: number;
    canChat?: boolean;
    canAccessUnassigned?: boolean;
  } | null;
};

/**
 * The one rule for who may see a parent's conversation with "الإدارة".
 *
 * The inbox, opening a thread, sending, the photo endpoint and the push
 * fan-out all ask through this file, so a change to the rule cannot reach
 * one of them and miss another. Like `halaqaIdsFor`, nothing here is stored:
 * scope is worked out per request, so moving a manager between halaqas takes
 * effect on their next request.
 *
 * A parent with no linked child has no chat at all, so every branch requires
 * at least one child.
 */
export async function chatParentWhere(
  prisma: PrismaService,
  user: ChatUser,
): Promise<Prisma.ParentWhereInput | null> {
  return (await chatScope(prisma, user))?.where ?? null;
}

/** A staff user's chat reach, read two ways from one rule. */
export interface ChatScope {
  /** Parents this user may see: at least one child inside the scope. */
  where: Prisma.ParentWhereInput;
  /**
   * Whether a child in `halaqaId` (null: unassigned) is inside the scope.
   * The inbox groups threads by halaqa with it, so a manager never gets a
   * group for a sibling's halaqa they do not manage.
   */
  covers: (halaqaId: number | null) => boolean;
}

/** Null when the user has no chat at all. */
export async function chatScope(
  prisma: PrismaService,
  user: ChatUser,
): Promise<ChatScope | null> {
  if (user.role === 'ADMIN') {
    return { where: { students: { some: {} } }, covers: () => true };
  }

  if (user.role !== 'MANAGER' || !user.manager?.canChat) return null;

  const scope = await halaqaIdsFor(prisma, user);
  const halaqaIds = Array.isArray(scope) ? scope : [];
  const unassigned = user.manager.canAccessUnassigned === true;
  return {
    where: {
      students: {
        some: {
          OR: [
            { halaqaId: { in: halaqaIds } },
            ...(unassigned ? [{ halaqaId: null }] : []),
          ],
        },
      },
    },
    covers: (halaqaId) =>
      halaqaId === null ? unassigned : halaqaIds.includes(halaqaId),
  };
}

/** Whether a staff user may see (and answer) parent `parentId`'s thread. */
export async function canStaffSeeParent(
  prisma: PrismaService,
  user: ChatUser,
  parentId: number,
): Promise<boolean> {
  const where = await chatParentWhere(prisma, user);
  if (!where) return false;
  const count = await prisma.parent.count({
    where: { AND: [where, { id: parentId }] },
  });
  return count > 0;
}

/**
 * Every active staff account that may see parent `parentId`'s thread: who a
 * parent's message is pushed to. The reverse reading of `chatParentWhere`.
 */
export async function staffUserIdsForParent(
  prisma: PrismaService,
  parentId: number,
): Promise<number[]> {
  const children = await prisma.student.findMany({
    where: { parentId },
    select: { halaqaId: true },
  });
  if (!children.length) return [];

  const halaqaIds = [
    ...new Set(
      children.map((c) => c.halaqaId).filter((id): id is number => id !== null),
    ),
  ];
  const hasUnassigned = children.some((c) => c.halaqaId === null);

  const staff = await prisma.user.findMany({
    where: {
      isActive: true,
      OR: [
        { role: 'ADMIN' },
        {
          role: 'MANAGER',
          manager: {
            canChat: true,
            OR: [
              { halaqas: { some: { halaqaId: { in: halaqaIds } } } },
              ...(hasUnassigned ? [{ canAccessUnassigned: true }] : []),
            ],
          },
        },
      ],
    },
    select: { id: true },
  });
  return staff.map((s) => s.id);
}

/**
 * The signed-in parent's own Parent id, or null when they may not chat: not
 * a parent, or no child linked to the account.
 */
export async function chatParentIdForParentUser(
  prisma: PrismaService,
  user: ChatUser,
): Promise<number | null> {
  const parentId = user.role === 'PARENT' ? user.parent?.id : undefined;
  if (!parentId) return null;
  const children = await prisma.student.count({ where: { parentId } });
  return children > 0 ? parentId : null;
}
