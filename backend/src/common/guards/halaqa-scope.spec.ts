import { ALL_HALAQAS, halaqaIdsFor } from './halaqa-scope';

const makePrisma = (rows: {
  managerHalaqas?: { halaqaId: number }[];
  teacherHalaqas?: { id: number }[];
  ownStudent?: { halaqaId: number | null } | null;
  children?: { halaqaId: number | null }[];
}) => ({
  managerHalaqa: {
    findMany: jest.fn().mockResolvedValue(rows.managerHalaqas ?? []),
  },
  halaqa: { findMany: jest.fn().mockResolvedValue(rows.teacherHalaqas ?? []) },
  student: {
    findUnique: jest.fn().mockResolvedValue(rows.ownStudent ?? null),
    findMany: jest.fn().mockResolvedValue(rows.children ?? []),
  },
});

describe('halaqaIdsFor', () => {
  it('gives an ADMIN every halaqa', async () => {
    const prisma = makePrisma({});

    await expect(
      halaqaIdsFor(prisma as never, { role: 'ADMIN', id: 1 }),
    ).resolves.toBe(ALL_HALAQAS);
  });

  it('gives a MANAGER only the halaqas assigned to them', async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }, { halaqaId: 7 }] });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'MANAGER', id: 2, manager: { id: 5 } }),
    ).resolves.toEqual([4, 7]);
    expect(prisma.managerHalaqa.findMany).toHaveBeenCalledWith({
      where: { managerId: 5 },
      select: { halaqaId: true },
    });
  });

  it('gives a TEACHER the halaqas she teaches', async () => {
    const prisma = makePrisma({ teacherHalaqas: [{ id: 9 }] });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'TEACHER', id: 3, teacher: { id: 8 } }),
    ).resolves.toEqual([9]);
  });

  // The lookup is by userId, not by the student id carried on the token — the
  // same reasoning StudentOwnershipGuard spells out: a token's claim is not
  // the database row the rule is supposed to trust.
  it('gives a STUDENT his own halaqa, looked up by userId', async () => {
    const prisma = makePrisma({ ownStudent: { halaqaId: 6 } });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'STUDENT', id: 11 }),
    ).resolves.toEqual([6]);
    expect(prisma.student.findUnique).toHaveBeenCalledWith({
      where: { userId: 11 },
      select: { halaqaId: true },
    });
  });

  it('gives an ADULT_STUDENT his own halaqa the same way', async () => {
    const prisma = makePrisma({ ownStudent: { halaqaId: 6 } });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'ADULT_STUDENT', id: 11 }),
    ).resolves.toEqual([6]);
  });

  it('gives a PARENT the union across their children', async () => {
    const prisma = makePrisma({
      children: [{ halaqaId: 4 }, { halaqaId: 7 }, { halaqaId: 4 }],
    });

    const scope = await halaqaIdsFor(prisma as never, {
      role: 'PARENT',
      id: 12,
      parent: { id: 3 },
    });

    expect(scope).toEqual([4, 7]);
  });

  it('skips a child who is in no halaqa yet', async () => {
    const prisma = makePrisma({ children: [{ halaqaId: null }, { halaqaId: 5 }] });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'PARENT', id: 12, parent: { id: 3 } }),
    ).resolves.toEqual([5]);
  });

  it('gives a student with no halaqa nothing rather than [null]', async () => {
    const prisma = makePrisma({ ownStudent: { halaqaId: null } });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'STUDENT', id: 11 }),
    ).resolves.toEqual([]);
  });

  // A role's sub-record can be missing — a TEACHER user whose teacher row was
  // deleted, say. That must read as "no halaqas", never as "all".
  it('gives nothing to a MANAGER with no manager row', async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }] });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'MANAGER', id: 2 }),
    ).resolves.toEqual([]);
    expect(prisma.managerHalaqa.findMany).not.toHaveBeenCalled();
  });

  it('gives nothing to an unrecognised role', async () => {
    const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }] });

    await expect(
      halaqaIdsFor(prisma as never, { role: 'SOMETHING_NEW', id: 2 }),
    ).resolves.toEqual([]);
  });

  it('gives nothing when there is no user at all', async () => {
    const prisma = makePrisma({});

    await expect(halaqaIdsFor(prisma as never, undefined)).resolves.toEqual([]);
  });
});
