jest.mock('./points-access', () => ({
  canViewStudent: jest.fn(),
  canAdjustUser: jest.fn(),
}));
jest.mock('../../common/guards/halaqa-scope', () => ({
  ALL_HALAQAS: 'ALL',
  halaqaIdsFor: jest.fn(),
}));
import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { halaqaIdsFor } from '../../common/guards/halaqa-scope';
import { CreatePointsDto } from './dto/points.dto';
import { PointsActor, canAdjustUser, canViewStudent } from './points-access';
import { PointsService } from './points.service';

const dec = (v: string) => new Prisma.Decimal(v);
const admin: PointsActor = { id: 1, role: 'ADMIN' };
const teacher: PointsActor = { id: 2, role: 'TEACHER', teacher: { id: 20 } };

const makePrisma = (over: Record<string, any> = {}) => ({
  pointEntry: {
    findMany: jest.fn().mockResolvedValue([]),
    aggregate: jest.fn().mockResolvedValue({ _sum: { amount: null } }),
    groupBy: jest.fn().mockResolvedValue([]),
    create: jest.fn().mockImplementation(({ data }) => Promise.resolve({ id: 9, ...data })),
    findUnique: jest.fn().mockResolvedValue(null),
    delete: jest.fn().mockResolvedValue({ id: 9 }),
  },
  student: {
    findUnique: jest.fn().mockResolvedValue({ userId: 70 }),
    findMany: jest.fn().mockResolvedValue([]),
  },
  ...over,
});
const svc = (prisma: any) => new PointsService(prisma);

beforeEach(() => {
  jest.mocked(canViewStudent).mockReset();
  jest.mocked(canAdjustUser).mockReset();
  jest.mocked(halaqaIdsFor).mockReset();
});

describe('PointsService.summaryForUser', () => {
  it('sums with the database, not in JS', async () => {
    const prisma = makePrisma();
    prisma.pointEntry.aggregate.mockResolvedValue({ _sum: { amount: dec('0.3') } });
    const result = await svc(prisma).summaryForUser(70);
    expect(result.total).toBe('0.3');
    expect(prisma.pointEntry.aggregate).toHaveBeenCalledWith({
      where: { userId: 70 },
      _sum: { amount: true },
    });
  });

  it('reports zero for an account with no entries', async () => {
    expect((await svc(makePrisma()).summaryForUser(70)).total).toBe('0');
  });

  it('returns amounts as exact strings, newest first', async () => {
    const prisma = makePrisma();
    prisma.pointEntry.findMany.mockResolvedValue([
      {
        id: 3,
        source: 'ABSENCE',
        amount: dec('-1'),
        date: new Date('2026-11-05'),
        reason: null,
        createdAt: new Date('2026-11-05T08:00:00Z'),
        createdBy: null,
      },
    ]);
    const result = await svc(prisma).summaryForUser(70);
    expect(result.entries[0].amount).toBe('-1');
    expect(prisma.pointEntry.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: 70 },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      }),
    );
  });
});

describe('PointsService.summaryForStudent', () => {
  it('refuses a student the actor may not see', async () => {
    jest.mocked(canViewStudent).mockResolvedValue(false);
    await expect(
      svc(makePrisma()).summaryForStudent(7, teacher),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('404s for an unknown student', async () => {
    const prisma = makePrisma();
    prisma.student.findUnique.mockResolvedValue(null);
    await expect(svc(prisma).summaryForStudent(7, admin)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it("returns the student's own account summary", async () => {
    jest.mocked(canViewStudent).mockResolvedValue(true);
    const prisma = makePrisma();
    prisma.pointEntry.aggregate.mockResolvedValue({ _sum: { amount: dec('-0.5') } });
    const result = await svc(prisma).summaryForStudent(7, admin);
    expect(result.total).toBe('-0.5');
    expect(prisma.pointEntry.aggregate).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 70 } }),
    );
  });
});

describe('PointsService.halaqaTotals', () => {
  it('refuses a halaqa outside the actor scope', async () => {
    jest.mocked(halaqaIdsFor).mockResolvedValue([12]);
    await expect(
      svc(makePrisma()).halaqaTotals(11, teacher),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('gives each student their total, zero when they have none', async () => {
    jest.mocked(halaqaIdsFor).mockResolvedValue([11]);
    const prisma = makePrisma();
    prisma.student.findMany.mockResolvedValue([
      { id: 7, userId: 70, user: { fullName: 'A', avatar: null } },
      { id: 8, userId: 80, user: { fullName: 'B', avatar: 'x.png' } },
    ]);
    prisma.pointEntry.groupBy.mockResolvedValue([
      { userId: 70, _sum: { amount: dec('2.5') } },
    ]);
    expect(await svc(prisma).halaqaTotals(11, teacher)).toEqual([
      { studentId: 7, userId: 70, fullName: 'A', avatar: null, total: '2.5' },
      { studentId: 8, userId: 80, fullName: 'B', avatar: 'x.png', total: '0' },
    ]);
  });

  it('lets the admin read any halaqa', async () => {
    jest.mocked(halaqaIdsFor).mockResolvedValue('ALL' as any);
    await expect(svc(makePrisma()).halaqaTotals(11, admin)).resolves.toEqual([]);
  });
});

describe('PointsService.create', () => {
  it('writes a manual entry with an exact amount', async () => {
    jest.mocked(canAdjustUser).mockResolvedValue('ok');
    const prisma = makePrisma();
    await svc(prisma).create({ userId: 70, amount: 2.5, reason: ' حفظ ممتاز ' }, teacher);
    expect(prisma.pointEntry.create).toHaveBeenCalledWith({
      data: {
        userId: 70,
        amount: '2.500',
        source: 'MANUAL',
        date: null,
        reason: 'حفظ ممتاز',
        createdById: 2,
      },
    });
  });

  it('stores a blank reason as no reason', async () => {
    jest.mocked(canAdjustUser).mockResolvedValue('ok');
    const prisma = makePrisma();
    await svc(prisma).create({ userId: 70, amount: -1, reason: '   ' }, admin);
    expect(prisma.pointEntry.create.mock.calls[0][0].data.reason).toBeNull();
    expect(prisma.pointEntry.create.mock.calls[0][0].data.amount).toBe('-1.000');
  });

  it.each([
    ['forbidden', ForbiddenException],
    ['not-found', NotFoundException],
    ['not-eligible', BadRequestException],
  ])('maps %s to its error', async (answer, error) => {
    jest.mocked(canAdjustUser).mockResolvedValue(answer as any);
    const prisma = makePrisma();
    await expect(
      svc(prisma).create({ userId: 70, amount: 1 }, teacher),
    ).rejects.toBeInstanceOf(error);
    expect(prisma.pointEntry.create).not.toHaveBeenCalled();
  });
});

describe('PointsService.remove', () => {
  const entry = (over: Record<string, any> = {}) => ({
    id: 9,
    userId: 70,
    source: 'MANUAL',
    createdById: 2,
    ...over,
  });

  it('404s for a missing entry', async () => {
    await expect(svc(makePrisma()).remove(9, admin)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('never deletes an automatic entry, not even for the admin', async () => {
    const prisma = makePrisma();
    prisma.pointEntry.findUnique.mockResolvedValue(entry({ source: 'ABSENCE' }));
    await expect(svc(prisma).remove(9, admin)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.pointEntry.delete).not.toHaveBeenCalled();
  });

  it("lets the admin remove someone else's manual entry", async () => {
    const prisma = makePrisma();
    prisma.pointEntry.findUnique.mockResolvedValue(entry({ createdById: 99 }));
    await svc(prisma).remove(9, admin);
    expect(prisma.pointEntry.delete).toHaveBeenCalledWith({ where: { id: 9 } });
  });

  it('lets a teacher remove their own entry', async () => {
    jest.mocked(canAdjustUser).mockResolvedValue('ok');
    const prisma = makePrisma();
    prisma.pointEntry.findUnique.mockResolvedValue(entry());
    await svc(prisma).remove(9, teacher);
    expect(prisma.pointEntry.delete).toHaveBeenCalled();
  });

  it('refuses a teacher removing an entry someone else made', async () => {
    jest.mocked(canAdjustUser).mockResolvedValue('ok');
    const prisma = makePrisma();
    prisma.pointEntry.findUnique.mockResolvedValue(entry({ createdById: 99 }));
    await expect(svc(prisma).remove(9, teacher)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('refuses a teacher whose student has since left their halaqa', async () => {
    jest.mocked(canAdjustUser).mockResolvedValue('forbidden');
    const prisma = makePrisma();
    prisma.pointEntry.findUnique.mockResolvedValue(entry());
    await expect(svc(prisma).remove(9, teacher)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(prisma.pointEntry.delete).not.toHaveBeenCalled();
  });
});

describe('CreatePointsDto', () => {
  const errors = async (body: object) =>
    (await validate(plainToInstance(CreatePointsDto, body))).map((e) => e.property);

  it('accepts a signed amount with up to two decimals', async () => {
    expect(await errors({ userId: 70, amount: -1.5 })).toEqual([]);
    expect(await errors({ userId: 70, amount: 2.25, reason: 'x' })).toEqual([]);
  });

  it.each([0, 2.555, 1001, -1001])('rejects amount %p', async (amount) => {
    expect(await errors({ userId: 70, amount })).toContain('amount');
  });

  it('rejects a reason over 300 characters', async () => {
    expect(await errors({ userId: 70, amount: 1, reason: 'a'.repeat(301) })).toContain(
      'reason',
    );
  });
});
