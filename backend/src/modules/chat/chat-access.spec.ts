import {
  canStaffSeeParent,
  chatParentIdForParentUser,
  chatParentWhere,
  chatScope,
  staffUserIdsForParent,
} from './chat-access';

const makePrisma = (rows: {
  managerHalaqas?: { halaqaId: number }[];
  children?: { halaqaId: number | null }[];
  parentCount?: number;
  staff?: { id: number }[];
}) => ({
  managerHalaqa: {
    findMany: jest.fn().mockResolvedValue(rows.managerHalaqas ?? []),
  },
  student: {
    findMany: jest.fn().mockResolvedValue(rows.children ?? []),
    count: jest.fn().mockResolvedValue(rows.children?.length ?? 0),
  },
  parent: { count: jest.fn().mockResolvedValue(rows.parentCount ?? 0) },
  user: { findMany: jest.fn().mockResolvedValue(rows.staff ?? []) },
});

const manager = (flags: {
  canChat?: boolean;
  canAccessUnassigned?: boolean;
}) => ({
  role: 'MANAGER',
  id: 20,
  manager: { id: 5, ...flags },
});

describe('chatParentWhere', () => {
  // A parent with no linked child has no chat at all, admins included.
  it('gives an admin every parent with a child', async () => {
    const prisma = makePrisma({});

    await expect(
      chatParentWhere(prisma as never, { role: 'ADMIN', id: 1 }),
    ).resolves.toEqual({ students: { some: {} } });
  });

  it('gives a manager without canChat nothing', async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }] });

    await expect(
      chatParentWhere(prisma as never, manager({ canChat: false })),
    ).resolves.toBeNull();
  });

  it('limits a manager with canChat to their halaqas', async () => {
    const prisma = makePrisma({
      managerHalaqas: [{ halaqaId: 4 }, { halaqaId: 7 }],
    });

    await expect(
      chatParentWhere(prisma as never, manager({ canChat: true })),
    ).resolves.toEqual({
      students: { some: { OR: [{ halaqaId: { in: [4, 7] } }] } },
    });
  });

  it('lets a manager with canAccessUnassigned reach unassigned children', async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }] });

    await expect(
      chatParentWhere(
        prisma as never,
        manager({ canChat: true, canAccessUnassigned: true }),
      ),
    ).resolves.toEqual({
      students: {
        some: { OR: [{ halaqaId: { in: [4] } }, { halaqaId: null }] },
      },
    });
  });

  it.each(['PARENT', 'TEACHER', 'STUDENT', 'ADULT_STUDENT'])(
    'gives a %s nothing',
    async (role) => {
      const prisma = makePrisma({});

      await expect(
        chatParentWhere(prisma as never, { role, id: 3 }),
      ).resolves.toBeNull();
    },
  );
});

describe('chatScope.covers', () => {
  it('covers every halaqa, and unassigned, for an admin', async () => {
    const scope = await chatScope(makePrisma({}) as never, {
      role: 'ADMIN',
      id: 1,
    });

    expect(scope?.covers(4)).toBe(true);
    expect(scope?.covers(null)).toBe(true);
  });

  it("covers only a manager's own halaqas", async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }] });

    const scope = await chatScope(prisma as never, manager({ canChat: true }));

    expect(scope?.covers(4)).toBe(true);
    expect(scope?.covers(7)).toBe(false);
    expect(scope?.covers(null)).toBe(false);
  });

  it('covers unassigned children with canAccessUnassigned', async () => {
    const prisma = makePrisma({ managerHalaqas: [] });

    const scope = await chatScope(
      prisma as never,
      manager({ canChat: true, canAccessUnassigned: true }),
    );

    expect(scope?.covers(null)).toBe(true);
  });
});

describe('canStaffSeeParent', () => {
  it('is true when the parent matches the scope', async () => {
    const prisma = makePrisma({ parentCount: 1 });

    await expect(
      canStaffSeeParent(prisma as never, { role: 'ADMIN', id: 1 }, 9),
    ).resolves.toBe(true);
    expect(prisma.parent.count).toHaveBeenCalledWith({
      where: { AND: [{ students: { some: {} } }, { id: 9 }] },
    });
  });

  it('is false outside the scope', async () => {
    const prisma = makePrisma({
      managerHalaqas: [{ halaqaId: 4 }],
      parentCount: 0,
    });

    await expect(
      canStaffSeeParent(prisma as never, manager({ canChat: true }), 9),
    ).resolves.toBe(false);
  });

  it('is false without canChat, without asking the database', async () => {
    const prisma = makePrisma({ parentCount: 1 });

    await expect(
      canStaffSeeParent(prisma as never, manager({ canChat: false }), 9),
    ).resolves.toBe(false);
    expect(prisma.parent.count).not.toHaveBeenCalled();
  });
});

describe('staffUserIdsForParent', () => {
  it('returns nobody for a parent with no children', async () => {
    const prisma = makePrisma({ children: [], staff: [{ id: 1 }] });

    await expect(staffUserIdsForParent(prisma as never, 9)).resolves.toEqual(
      [],
    );
    expect(prisma.user.findMany).not.toHaveBeenCalled();
  });

  it('asks for active admins and in-scope chat managers only', async () => {
    const prisma = makePrisma({
      children: [{ halaqaId: 4 }, { halaqaId: null }, { halaqaId: 4 }],
      staff: [{ id: 1 }, { id: 20 }],
    });

    await expect(staffUserIdsForParent(prisma as never, 9)).resolves.toEqual([
      1, 20,
    ]);
    expect(prisma.user.findMany).toHaveBeenCalledWith({
      where: {
        isActive: true,
        OR: [
          { role: 'ADMIN' },
          {
            role: 'MANAGER',
            manager: {
              canChat: true,
              OR: [
                { halaqas: { some: { halaqaId: { in: [4] } } } },
                { canAccessUnassigned: true },
              ],
            },
          },
        ],
      },
      select: { id: true },
    });
  });

  it('leaves out the unassigned grant when every child has a halaqa', async () => {
    const prisma = makePrisma({ children: [{ halaqaId: 4 }] });

    await staffUserIdsForParent(prisma as never, 9);

    const where = prisma.user.findMany.mock.calls[0][0].where;
    expect(where.OR[1].manager.OR).toEqual([
      { halaqas: { some: { halaqaId: { in: [4] } } } },
    ]);
  });
});

describe('chatParentIdForParentUser', () => {
  const parent = { role: 'PARENT', id: 30, parent: { id: 9 } };

  it('returns the parent id when they have a child', async () => {
    const prisma = makePrisma({ children: [{ halaqaId: 4 }] });

    await expect(
      chatParentIdForParentUser(prisma as never, parent),
    ).resolves.toBe(9);
  });

  it('returns null when the parent has no children', async () => {
    const prisma = makePrisma({ children: [] });

    await expect(
      chatParentIdForParentUser(prisma as never, parent),
    ).resolves.toBeNull();
  });

  it('returns null for a non-parent', async () => {
    const prisma = makePrisma({ children: [{ halaqaId: 4 }] });

    await expect(
      chatParentIdForParentUser(prisma as never, { role: 'ADMIN', id: 1 }),
    ).resolves.toBeNull();
  });
});
