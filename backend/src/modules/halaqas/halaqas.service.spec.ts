import { BadRequestException } from '@nestjs/common';
import { HalaqasService } from './halaqas.service';

// The service only needs to read the roles of the students being connected,
// so the mock answers that one query and records the write it would make.
const makeService = (roles: Array<{ id: number; role: string }>) => {
  const prisma = {
    student: {
      findMany: jest
        .fn()
        .mockResolvedValue(
          roles.map((r) => ({ id: r.id, user: { role: r.role } })),
        ),
    },
    halaqa: {
      findUnique: jest.fn().mockResolvedValue({ id: 1, isAdult: false }),
      create: jest.fn().mockResolvedValue({ id: 1 }),
      update: jest.fn().mockResolvedValue({ id: 1 }),
    },
  };
  return { service: new HalaqasService(prisma as any), prisma };
};

describe('HalaqasService enrolment validation', () => {
  it('refuses a child student in an adults halaqa', async () => {
    const { service } = makeService([{ id: 7, role: 'STUDENT' }]);

    await expect(
      service.create({
        name: 'حلقة الكبار',
        teacherId: 1,
        isAdult: true,
        studentIds: [7],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses an adult student in a normal halaqa', async () => {
    const { service } = makeService([{ id: 21, role: 'ADULT_STUDENT' }]);

    await expect(
      service.create({
        name: 'حلقة النور',
        teacherId: 1,
        studentIds: [21],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts adult students in an adults halaqa', async () => {
    const { service, prisma } = makeService([
      { id: 21, role: 'ADULT_STUDENT' },
      { id: 22, role: 'ADULT_STUDENT' },
    ]);

    await service.create({
      name: 'حلقة الكبار',
      teacherId: 1,
      isAdult: true,
      studentIds: [21, 22],
    });

    expect(prisma.halaqa.create).toHaveBeenCalled();
  });

  it('skips the check when no students are being connected', async () => {
    const { service, prisma } = makeService([]);

    await service.create({ name: 'حلقة النور', teacherId: 1 });

    expect(prisma.student.findMany).not.toHaveBeenCalled();
    expect(prisma.halaqa.create).toHaveBeenCalled();
  });
});

describe('HalaqasService.update — enrolment revalidation on an isAdult flip', () => {
  // Two different `student.findMany` shapes are exercised here: the fix
  // loads the halaqa's currently-connected roster by `halaqaId` first, then
  // feeds those ids through the same role-fetch `assertEnrolmentMatches`
  // already uses (keyed by `id: { in: [...] }`). The mock tells the two
  // calls apart by which `where` shape they were given.
  const makeUpdateService = (opts: {
    halaqaIsAdult: boolean;
    rosterIds: number[];
    rosterRole: string;
  }) => {
    const prisma = {
      halaqa: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 1, isAdult: opts.halaqaIsAdult }),
        update: jest.fn().mockResolvedValue({ id: 1 }),
      },
      student: {
        findMany: jest.fn((args: any) => {
          if (args?.where?.halaqaId !== undefined) {
            return Promise.resolve(opts.rosterIds.map((id) => ({ id })));
          }
          return Promise.resolve(
            opts.rosterIds.map((id) => ({
              id,
              user: { role: opts.rosterRole },
            })),
          );
        }),
      },
    };
    return { service: new HalaqasService(prisma as any), prisma };
  };

  it('refuses converting a halaqa full of children to adults without re-picking the roster', async () => {
    const { service } = makeUpdateService({
      halaqaIsAdult: false,
      rosterIds: [7, 8],
      rosterRole: 'STUDENT',
    });

    await expect(
      service.update(1, { isAdult: true } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('allows converting a halaqa that currently has no students at all', async () => {
    const { service, prisma } = makeUpdateService({
      halaqaIsAdult: false,
      rosterIds: [],
      rosterRole: 'STUDENT',
    });

    await service.update(1, { isAdult: true } as any);

    expect(prisma.halaqa.update).toHaveBeenCalled();
  });

  it('does not query the roster when isAdult is not actually changing', async () => {
    const { service, prisma } = makeUpdateService({
      halaqaIsAdult: false,
      rosterIds: [7],
      rosterRole: 'STUDENT',
    });

    await service.update(1, { name: 'حلقة جديدة' } as any);

    expect(prisma.student.findMany).not.toHaveBeenCalled();
    expect(prisma.halaqa.update).toHaveBeenCalled();
  });
});

/// `GET /halaqas` is read by two teacher screens to find a student's halaqa,
/// so a teacher cannot simply be denied it. The response is narrowed instead:
/// the fine rates it now carries are another teacher's business, not hers.
describe('HalaqasService.findAll scoping', () => {
  const makeService = () => {
    const prisma = {
      halaqa: { findMany: jest.fn().mockResolvedValue([]) },
    };
    return { service: new HalaqasService(prisma as any), prisma };
  };

  const whereOf = (prisma: { halaqa: { findMany: jest.Mock } }) =>
    prisma.halaqa.findMany.mock.calls[0][0].where;

  it('gives a teacher only her own halaqas', async () => {
    const { service, prisma } = makeService();

    await service.findAll({ id: 50, role: 'TEACHER', teacher: { id: 3 } });

    expect(whereOf(prisma)).toEqual({ teacherId: 3 });
  });

  it('gives an admin every halaqa', async () => {
    const { service, prisma } = makeService();

    await service.findAll({ id: 1, role: 'ADMIN' });

    expect(whereOf(prisma)).toEqual({});
  });

  // Fail closed, the same way the fines and attendance guards do: a
  // teacher-role account with no teacher row teaches nothing, so it must not
  // fall through to the unfiltered list.
  it('gives a teacher with no teacher profile nothing at all', async () => {
    const { service, prisma } = makeService();

    await expect(
      service.findAll({ id: 50, role: 'TEACHER' }),
    ).resolves.toEqual([]);
    expect(prisma.halaqa.findMany).not.toHaveBeenCalled();
  });

  it('leaves the query unfiltered when no actor is supplied', async () => {
    const { service, prisma } = makeService();

    await service.findAll();

    expect(whereOf(prisma)).toEqual({});
  });
});
