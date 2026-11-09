jest.mock('../../common/guards/halaqa-scope', () => ({
  ALL_HALAQAS: 'ALL',
  halaqaIdsFor: jest.fn(),
}));
import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { halaqaIdsFor } from '../../common/guards/halaqa-scope';
import { PrismaService } from '../../prisma/prisma.service';
import type { PointsActor } from '../points/points-access';
import { StudentOfMonthService } from './student-of-month.service';

const dec = (v: string) => new Prisma.Decimal(v);
const teacher: PointsActor = { id: 2, role: 'TEACHER', teacher: { id: 20 } };
const DEC_15 = new Date('2026-12-15T10:00:00Z');
const NOV_09 = new Date('2026-11-09T10:00:00Z');

const students = [
  { id: 1, userId: 11, user: { fullName: 'أحمد', avatar: null } },
  { id: 2, userId: 12, user: { fullName: 'بلال', avatar: 'a.jpg' } },
  { id: 3, userId: 13, user: { fullName: 'جابر', avatar: null } },
];

const makePrisma = () => ({
  halaqa: {
    findMany: jest.fn().mockResolvedValue([{ id: 5, name: 'حلقة النور' }]),
    findUnique: jest.fn().mockResolvedValue({ teacherId: 20 }),
  },
  student: { findMany: jest.fn().mockResolvedValue(students) },
  pointEntry: {
    groupBy: jest.fn().mockResolvedValue([
      { userId: 11, _sum: { amount: dec('20') } },
      { userId: 12, _sum: { amount: dec('5') } },
      { userId: 13, _sum: { amount: dec('17') } },
    ]),
  },
  fineEntry: {
    groupBy: jest.fn().mockResolvedValue([
      { studentId: 1, kind: 'CHARGE', _sum: { amount: 400 } },
      { studentId: 1, kind: 'REDUCTION', _sum: { amount: 50 } },
    ]),
  },
  studentOfMonth: {
    findUnique: jest.fn().mockResolvedValue(null),
    findMany: jest.fn().mockResolvedValue([]),
    create: jest
      .fn()
      .mockImplementation(({ data }) => Promise.resolve({ id: 1, ...data })),
  },
});
type Mock = ReturnType<typeof makePrisma>;
const svc = (prisma: Mock) =>
  new StudentOfMonthService(prisma as unknown as PrismaService);
const whereOf = (fn: jest.Mock): unknown =>
  (fn.mock.calls[0] as [{ where: unknown }])[0].where;

beforeEach(() => jest.mocked(halaqaIdsFor).mockReset());

describe('StudentOfMonthService.pending', () => {
  it('ranks the month with fines taken off, ties all on top', async () => {
    const prisma = makePrisma();
    const [pick] = await svc(prisma).pending(teacher, DEC_15);

    expect(pick).toMatchObject({ halaqaId: 5, month: '2026-11' });
    // 20 points with 350 net fines is 17, level with جابر's 17.
    expect(pick.candidates.map((c) => [c.studentId, c.score, c.isTop])).toEqual(
      [
        [1, '17.000', true],
        [3, '17.000', true],
        [2, '5.000', false],
      ],
    );
    expect(pick.candidates[0].finesPenalty).toBe(3);
  });

  it('counts only the month: dated rows by day, manual rows by Algiers time', async () => {
    const prisma = makePrisma();
    await svc(prisma).pending(teacher, DEC_15);

    expect((whereOf(prisma.pointEntry.groupBy) as { OR: unknown }).OR).toEqual([
      {
        date: {
          gte: new Date('2026-11-01T00:00:00Z'),
          lt: new Date('2026-12-01T00:00:00Z'),
        },
      },
      {
        date: null,
        createdAt: {
          gte: new Date('2026-10-31T23:00:00Z'),
          lt: new Date('2026-11-30T23:00:00Z'),
        },
      },
    ]);
  });

  it('skips halaqas already validated this month', async () => {
    const prisma = makePrisma();
    await svc(prisma).pending(teacher, DEC_15);
    expect(whereOf(prisma.halaqa.findMany)).toEqual({
      teacherId: 20,
      studentsOfMonth: { none: { month: '2026-11' } },
    });
  });

  it('asks nothing for a halaqa without students', async () => {
    const prisma = makePrisma();
    prisma.student.findMany.mockResolvedValue([]);
    expect(await svc(prisma).pending(teacher, DEC_15)).toEqual([]);
  });

  it('asks nothing before the first month with points has ended', async () => {
    const prisma = makePrisma();
    expect(await svc(prisma).pending(teacher, NOV_09)).toEqual([]);
    expect(prisma.halaqa.findMany).not.toHaveBeenCalled();
  });
});

describe('StudentOfMonthService.select', () => {
  it('accepts a student who is not the top scorer, and records that', async () => {
    const prisma = makePrisma();
    await svc(prisma).select(teacher, { halaqaId: 5, studentId: 2 }, DEC_15);
    expect(prisma.studentOfMonth.create).toHaveBeenCalledWith({
      data: {
        halaqaId: 5,
        month: '2026-11',
        studentId: 2,
        score: '5.000',
        wasTopScorer: false,
        selectedById: 2,
      },
    });
  });

  it('refuses another teacher', async () => {
    const prisma = makePrisma();
    prisma.halaqa.findUnique.mockResolvedValue({ teacherId: 99 });
    await expect(
      svc(prisma).select(teacher, { halaqaId: 5, studentId: 1 }, DEC_15),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('refuses a student from another halaqa', async () => {
    const prisma = makePrisma();
    await expect(
      svc(prisma).select(teacher, { halaqaId: 5, studentId: 77 }, DEC_15),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses a second pick for the same month', async () => {
    const prisma = makePrisma();
    prisma.studentOfMonth.findUnique.mockResolvedValue({ id: 1 });
    await expect(
      svc(prisma).select(teacher, { halaqaId: 5, studentId: 1 }, DEC_15),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('turns a race on the unique index into a conflict', async () => {
    const prisma = makePrisma();
    prisma.studentOfMonth.create.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('dup', {
        code: 'P2002',
        clientVersion: 'x',
      }),
    );
    await expect(
      svc(prisma).select(teacher, { halaqaId: 5, studentId: 1 }, DEC_15),
    ).rejects.toBeInstanceOf(ConflictException);
  });
});

describe('StudentOfMonthService.shown', () => {
  it('reads only the halaqas in scope, for the judged month', async () => {
    const prisma = makePrisma();
    jest.mocked(halaqaIdsFor).mockResolvedValue([5]);
    prisma.studentOfMonth.findMany.mockResolvedValue([
      {
        halaqaId: 5,
        month: '2026-11',
        halaqa: { name: 'حلقة النور' },
        student: { id: 2, user: { fullName: 'بلال', avatar: 'a.jpg' } },
      },
    ]);
    const shown = await svc(prisma).shown(
      { id: 40, role: 'PARENT', parent: { id: 4 } },
      DEC_15,
    );
    expect(whereOf(prisma.studentOfMonth.findMany)).toEqual({
      month: '2026-11',
      halaqaId: { in: [5] },
    });
    expect(shown).toEqual([
      {
        halaqaId: 5,
        halaqaName: 'حلقة النور',
        month: '2026-11',
        student: { id: 2, fullName: 'بلال', avatar: 'a.jpg' },
      },
    ]);
    // Classmates never see anyone's score.
    expect(shown[0]).not.toHaveProperty('score');
  });

  it('shows nothing to someone with no halaqa', async () => {
    const prisma = makePrisma();
    jest.mocked(halaqaIdsFor).mockResolvedValue([]);
    expect(await svc(prisma).shown(teacher, DEC_15)).toEqual([]);
    expect(prisma.studentOfMonth.findMany).not.toHaveBeenCalled();
  });
});
