import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { FinesService } from './fines.service';

const entry = (kind: string, amount: number, source = 'MANUAL') => ({
  id: 1,
  studentId: 7,
  kind,
  amount,
  source,
});

// `halaqaTeacherId` is who owns the student's halaqa, which is what the
// teacher restriction compares the actor against.
const makeService = (
  entries: Array<Record<string, unknown>>,
  halaqaTeacherId: number | null = 3,
) => {
  const prisma = {
    fineEntry: {
      findMany: jest.fn().mockResolvedValue(entries),
      findUnique: jest.fn().mockResolvedValue(entries[0] ?? null),
      create: jest.fn().mockImplementation(({ data }) => ({ id: 9, ...data })),
      delete: jest.fn().mockResolvedValue(entries[0] ?? null),
    },
    student: {
      findUnique: jest.fn().mockResolvedValue({
        halaqa: halaqaTeacherId === null ? null : { teacherId: halaqaTeacherId },
      }),
    },
  };
  return { service: new FinesService(prisma as any), prisma };
};

// The teacher who owns the halaqa these fixtures put the student in.
const TEACHER = { id: 50, role: 'TEACHER', teacher: { id: 3 } };
const ADMIN = { id: 1, role: 'ADMIN' };
const MANAGER = { id: 2, role: 'MANAGER' };

describe('FinesService.findByStudent', () => {
  it('sums charges minus reductions', async () => {
    const { service } = makeService([
      entry('CHARGE', 50, 'ABSENCE'),
      entry('CHARGE', 20, 'LATE'),
      entry('REDUCTION', 30),
    ]);

    await expect(service.findByStudent(7)).resolves.toMatchObject({ balance: 40 });
  });

  // Charges can be withdrawn but reductions cannot, so the sum can legitimately
  // fall below zero. Nobody owes a negative amount, so the reading clamps while
  // the rows stay honest about what happened.
  it('clamps a negative balance to zero', async () => {
    const { service } = makeService([entry('REDUCTION', 30)]);

    await expect(service.findByStudent(7)).resolves.toMatchObject({ balance: 0 });
  });

  it('reports zero for a student with no entries', async () => {
    const { service } = makeService([]);

    await expect(service.findByStudent(7)).resolves.toEqual({
      balance: 0,
      entries: [],
    });
  });
});

describe('FinesService.create', () => {
  it('records a manual charge', async () => {
    const { service, prisma } = makeService([]);

    await service.create(
      { studentId: 7, kind: 'CHARGE', amount: 40, reason: 'إتلاف مصحف' } as any,
      TEACHER,
    );

    expect(prisma.fineEntry.create).toHaveBeenCalledWith({
      data: {
        studentId: 7,
        kind: 'CHARGE',
        amount: 40,
        reason: 'إتلاف مصحف',
        source: 'MANUAL',
        date: null,
        createdById: 50,
      },
    });
  });

  it('refuses a reduction larger than the balance', async () => {
    const { service } = makeService([entry('CHARGE', 20, 'LATE')]);

    await expect(
      service.create(
        { studentId: 7, kind: 'REDUCTION', amount: 50, reason: 'دفع' } as any,
        TEACHER,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('allows a reduction exactly clearing the balance', async () => {
    const { service, prisma } = makeService([entry('CHARGE', 20, 'LATE')]);

    await service.create(
      { studentId: 7, kind: 'REDUCTION', amount: 20, reason: 'دفع' } as any,
      TEACHER,
    );

    expect(prisma.fineEntry.create).toHaveBeenCalled();
  });

  // Reads let any teacher see any student, which is the established rule in
  // StudentOwnershipGuard. Moving money is where that stops being good enough.
  it('refuses a teacher who does not run the student\'s halaqa', async () => {
    const { service } = makeService([], 99);

    await expect(
      service.create(
        { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
        TEACHER,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets an admin charge any student', async () => {
    const { service, prisma } = makeService([], 99);

    await service.create(
      { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
      ADMIN,
    );

    expect(prisma.fineEntry.create).toHaveBeenCalled();
  });

  // Two undefineds must not cancel out into a pass: a teacher-role actor with
  // no teacher profile is malformed and must be refused regardless of whether
  // the student happens to have no halaqa either.
  it('refuses a teacher-role actor with no teacher profile, even against a student with no halaqa', async () => {
    const { service } = makeService([], null);

    await expect(
      service.create(
        { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
        { id: 50, role: 'TEACHER' },
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  // A student with no halaqa has no owning teacher, so no teacher — however
  // well-formed the actor — may pass this check for him.
  it('refuses a teacher with a valid profile when the student has no halaqa', async () => {
    const { service } = makeService([], null);

    await expect(
      service.create(
        { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
        TEACHER,
      ),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets an admin charge a student with no halaqa', async () => {
    const { service, prisma } = makeService([], null);

    await service.create(
      { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
      ADMIN,
    );

    expect(prisma.fineEntry.create).toHaveBeenCalled();
  });

  it('lets a manager charge a student with no halaqa', async () => {
    const { service, prisma } = makeService([], null);

    await service.create(
      { studentId: 7, kind: 'CHARGE', amount: 40 } as any,
      MANAGER,
    );

    expect(prisma.fineEntry.create).toHaveBeenCalled();
  });
});

describe('FinesService.remove', () => {
  it('deletes a manual entry', async () => {
    const { service, prisma } = makeService([entry('CHARGE', 40)]);

    await service.remove(1, TEACHER);

    expect(prisma.fineEntry.delete).toHaveBeenCalledWith({ where: { id: 1 } });
  });

  // An auto-charge belongs to its attendance row. Deleting it here would leave
  // the day marked absent with nothing owed, and the next save would recreate
  // it anyway.
  it('refuses to delete an auto-charge', async () => {
    const { service } = makeService([entry('CHARGE', 50, 'ABSENCE')]);

    await expect(service.remove(1, TEACHER)).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('refuses a teacher who does not run the student\'s halaqa', async () => {
    const { service } = makeService([entry('CHARGE', 40)], 99);

    await expect(service.remove(1, TEACHER)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('reports a missing entry', async () => {
    const { service } = makeService([]);

    await expect(service.remove(404, TEACHER)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
