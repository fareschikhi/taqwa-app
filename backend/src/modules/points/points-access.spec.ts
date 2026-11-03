import { PointsActor, canAdjustUser, canViewStudent } from './points-access';

type StudentRow = { userId: number; parentId: number | null; halaqaId: number | null };
type UserRow = { role: string; student: { halaqaId: number | null } | null };

const makePrisma = (opts: {
  student?: StudentRow | null;
  user?: UserRow | null;
  teacherHalaqas?: number[];
  managerHalaqas?: number[];
}) => ({
  student: { findUnique: jest.fn().mockResolvedValue(opts.student ?? null) },
  user: { findUnique: jest.fn().mockResolvedValue(opts.user ?? null) },
  halaqa: {
    findMany: jest
      .fn()
      .mockResolvedValue((opts.teacherHalaqas ?? []).map((id) => ({ id }))),
  },
  managerHalaqa: {
    findMany: jest
      .fn()
      .mockResolvedValue(
        (opts.managerHalaqas ?? []).map((halaqaId) => ({ halaqaId })),
      ),
  },
});

const admin: PointsActor = { id: 1, role: 'ADMIN' };
const teacher: PointsActor = { id: 2, role: 'TEACHER', teacher: { id: 20 } };
const manager: PointsActor = { id: 3, role: 'MANAGER', manager: { id: 30 } };
const parent: PointsActor = { id: 4, role: 'PARENT', parent: { id: 5 } };
const adult: PointsActor = { id: 6, role: 'ADULT_STUDENT' };

const child = (over: Partial<StudentRow> = {}): StudentRow => ({
  userId: 70,
  parentId: 5,
  halaqaId: 11,
  ...over,
});
const view = (prisma: any, actor: PointsActor) => canViewStudent(prisma, actor, 7);

describe('canViewStudent', () => {
  it('admin sees any student', async () => {
    expect(await view(makePrisma({ student: child() }), admin)).toBe(true);
  });

  it('parent sees own child', async () => {
    expect(await view(makePrisma({ student: child() }), parent)).toBe(true);
  });

  it("parent cannot see another family's child", async () => {
    expect(
      await view(makePrisma({ student: child({ parentId: 99 }) }), parent),
    ).toBe(false);
  });

  it('parent cannot see a classmate through the shared halaqa', async () => {
    expect(
      await view(makePrisma({ student: child({ parentId: null }) }), parent),
    ).toBe(false);
  });

  it('adult student sees only themselves', async () => {
    expect(await view(makePrisma({ student: child({ userId: 6 }) }), adult)).toBe(true);
    expect(await view(makePrisma({ student: child({ userId: 71 }) }), adult)).toBe(false);
  });

  it('teacher sees a student in their halaqa', async () => {
    expect(
      await view(makePrisma({ student: child(), teacherHalaqas: [11] }), teacher),
    ).toBe(true);
  });

  it('teacher cannot see a student in another halaqa', async () => {
    expect(
      await view(makePrisma({ student: child(), teacherHalaqas: [12] }), teacher),
    ).toBe(false);
  });

  it('manager sees a student in an assigned halaqa', async () => {
    expect(
      await view(makePrisma({ student: child(), managerHalaqas: [11] }), manager),
    ).toBe(true);
  });

  it('manager cannot see a halaqa-less student even with canAccessUnassigned', async () => {
    const m = { ...manager, manager: { id: 30, canAccessUnassigned: true } };
    expect(
      await view(
        makePrisma({ student: child({ halaqaId: null }), managerHalaqas: [11] }),
        m,
      ),
    ).toBe(false);
  });

  it('missing student is not visible', async () => {
    expect(await view(makePrisma({ student: null }), admin)).toBe(false);
  });
});

describe('canAdjustUser', () => {
  const adjust = (prisma: any, actor: PointsActor) => canAdjustUser(prisma, actor, 70);
  const studentUser = (halaqaId: number | null = 11): UserRow => ({
    role: 'STUDENT',
    student: { halaqaId },
  });

  it('admin may adjust a teacher', async () => {
    expect(await adjust(makePrisma({ user: { role: 'TEACHER', student: null } }), admin)).toBe('ok');
  });

  it('admin may adjust a manager', async () => {
    expect(await adjust(makePrisma({ user: { role: 'MANAGER', student: null } }), admin)).toBe('ok');
  });

  it('admin may adjust any student', async () => {
    expect(await adjust(makePrisma({ user: studentUser(null) }), admin)).toBe('ok');
  });

  it('admin cannot adjust a parent', async () => {
    expect(await adjust(makePrisma({ user: { role: 'PARENT', student: null } }), admin)).toBe('not-eligible');
  });

  it('admin cannot adjust an admin', async () => {
    expect(await adjust(makePrisma({ user: { role: 'ADMIN', student: null } }), admin)).toBe('not-eligible');
  });

  it('teacher may adjust a student in their halaqa', async () => {
    expect(
      await adjust(makePrisma({ user: studentUser(), teacherHalaqas: [11] }), teacher),
    ).toBe('ok');
  });

  it('teacher may adjust an adult student in their halaqa', async () => {
    expect(
      await adjust(
        makePrisma({
          user: { role: 'ADULT_STUDENT', student: { halaqaId: 11 } },
          teacherHalaqas: [11],
        }),
        teacher,
      ),
    ).toBe('ok');
  });

  it('teacher cannot adjust a student in another halaqa', async () => {
    expect(
      await adjust(makePrisma({ user: studentUser(), teacherHalaqas: [12] }), teacher),
    ).toBe('forbidden');
  });

  it('staff cannot adjust staff', async () => {
    expect(
      await adjust(
        makePrisma({ user: { role: 'MANAGER', student: null }, teacherHalaqas: [11] }),
        teacher,
      ),
    ).toBe('forbidden');
  });

  it('manager cannot adjust a halaqa-less student', async () => {
    expect(
      await adjust(makePrisma({ user: studentUser(null), managerHalaqas: [11] }), manager),
    ).toBe('forbidden');
  });

  it('parent cannot adjust anyone, not even their own child', async () => {
    expect(await adjust(makePrisma({ user: studentUser() }), parent)).toBe('forbidden');
  });

  it('unknown user is not found', async () => {
    expect(await adjust(makePrisma({ user: null }), admin)).toBe('not-found');
  });
});
