import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { TeachersService } from './teachers.service';

describe('TeachersService.remove', () => {
  const makePrisma = (teacher: { id: number; userId: number } | null) => ({
    teacher: { findUnique: jest.fn().mockResolvedValue(teacher) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: teacher?.userId }),
      update: jest.fn(),
    },
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 5, userId: 21 });
    const service = new TeachersService(prisma as any);

    await service.remove(5);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 21 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 5, userId: 21 });
    const service = new TeachersService(prisma as any);

    await service.remove(5);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

// Points, fines and announcements keep their author (onDelete: Restrict),
  // so an account that made any of them cannot be hard-deleted. The admin
  // must get a sentence, not Prisma's English error text.
  it('explains in Arabic when the account still has records', async () => {
    const prisma = makePrisma({ id: 5, userId: 21 });
    prisma.user.delete.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('Foreign key constraint violated', {
        code: 'P2003',
        clientVersion: 'test',
      }),
    );

    const err = await new TeachersService(prisma as any).remove(5).catch((e) => e);

    expect(err).toBeInstanceOf(ConflictException);
    expect(err.message).toBe(
      'لا يمكن حذف هذا الحساب لأن له سجلات مرتبطة (نقاط أو غرامات أو إعلانات). عطّل الحساب بدلاً من ذلك.',
    );
  });

  it('throws NotFoundException when the teacher does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new TeachersService(prisma as any);

    await expect(service.remove(5)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});

// A password an admin sets is a temporary one: the teacher replaces it on
// their next login.
describe('TeachersService passwords', () => {
  const makePrisma = () => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42, teacher: { id: 6 } }),
      update: jest.fn().mockResolvedValue({ id: 42 }),
    },
    teacher: { findUnique: jest.fn().mockResolvedValue({ id: 6, userId: 42 }) },
  });

  const makeService = (prisma: ReturnType<typeof makePrisma>) => {
    const service = new TeachersService(prisma as any);
    jest.spyOn(service, 'findOne').mockResolvedValue({} as any);
    return service;
  };

  it('makes a new teacher change the password on first login', async () => {
    const prisma = makePrisma();

    await makeService(prisma).create({
      fullName: 'Amine Rahmani',
      phone: '4400',
      password: 'secret123',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('makes the teacher change a password an admin reset', async () => {
    const prisma = makePrisma();

    await makeService(prisma).update(6, { password: 'secret123' } as any);

    expect(prisma.user.update.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('leaves the flag alone when the password is not touched', async () => {
    const prisma = makePrisma();

    await makeService(prisma).update(6, { fullName: 'Amine R.' } as any);

    expect(prisma.user.update.mock.calls[0][0].data).not.toHaveProperty(
      'mustChangePassword',
    );
  });
});

// A teacher with several halaqas looks at one at a time; the dashboard
// aggregates narrow to it, and still only within the teacher's own halaqas.
describe('TeachersService dashboard scoped to one halaqa', () => {
  const makePrisma = () => ({
    student: { findMany: jest.fn().mockResolvedValue([]) },
    attendance: { count: jest.fn().mockResolvedValue(0) },
  });

  const cases: [string, (s: TeachersService, h?: number) => Promise<unknown>][] =
    [
      ['attendance summary', (s, h) => s.getTeacherAttendanceSummary(3, h)],
      ['revision needed', (s, h) => s.getRevisionNeeded(3, h)],
      ['memorization progress', (s, h) => s.getMemorizationProgress(3, h)],
    ];

  it.each(cases)('%s keeps to the given halaqa', async (_, call) => {
    const prisma = makePrisma();

    await call(new TeachersService(prisma as any), 9);

    expect(prisma.student.findMany.mock.calls[0][0].where).toEqual({
      halaqa: { teacherId: 3, id: 9 },
    });
  });

  it.each(cases)('%s covers every halaqa without one', async (_, call) => {
    const prisma = makePrisma();

    await call(new TeachersService(prisma as any));

    expect(prisma.student.findMany.mock.calls[0][0].where).toEqual({
      halaqa: { teacherId: 3 },
    });
  });
});

// معلم مشرف is an on/off flag; the level comes from the teacher's halaqas, so
// it may only be switched on once he runs a halaqa that has a level.
describe('TeachersService supervisor flag', () => {
  const makePrisma = (isSupervisor: boolean, levelledHalaqas: number) => ({
    user: { update: jest.fn().mockResolvedValue({ id: 42 }) },
    teacher: {
      findUnique: jest
        .fn()
        .mockResolvedValue({ id: 6, userId: 42, isSupervisor }),
    },
    halaqa: { count: jest.fn().mockResolvedValue(levelledHalaqas) },
  });

  const makeService = (prisma: ReturnType<typeof makePrisma>) => {
    const service = new TeachersService(prisma as any);
    jest.spyOn(service, 'findOne').mockResolvedValue({} as any);
    return service;
  };

  const teacherData = (prisma: ReturnType<typeof makePrisma>) =>
    prisma.user.update.mock.calls[0][0].data.teacher;

  it('switches on a teacher who runs a levelled halaqa', async () => {
    const prisma = makePrisma(false, 1);

    await makeService(prisma).update(6, { isSupervisor: true } as any);

    expect(prisma.halaqa.count).toHaveBeenCalledWith({
      where: { teacherId: 6, level: { not: null } },
    });
    expect(teacherData(prisma)).toEqual({ update: { isSupervisor: true } });
  });

  it('refuses to switch on a teacher with no levelled halaqa', async () => {
    const prisma = makePrisma(false, 0);

    await expect(
      makeService(prisma).update(6, { isSupervisor: true } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('always lets the admin switch it off', async () => {
    const prisma = makePrisma(true, 0);

    await makeService(prisma).update(6, { isSupervisor: false } as any);

    expect(prisma.halaqa.count).not.toHaveBeenCalled();
    expect(teacherData(prisma)).toEqual({ update: { isSupervisor: false } });
  });

  it('saves other fields of a supervisor who lost his halaqa', async () => {
    const prisma = makePrisma(true, 0);

    await makeService(prisma).update(6, {
      fullName: 'Amine Rahmani',
      isSupervisor: true,
    } as any);

    expect(prisma.halaqa.count).not.toHaveBeenCalled();
    expect(prisma.user.update).toHaveBeenCalled();
  });

  it('leaves the flag alone when it is not sent', async () => {
    const prisma = makePrisma(false, 0);

    await makeService(prisma).update(6, { canPostNews: true } as any);

    expect(teacherData(prisma)).toEqual({ update: { canPostNews: true } });
  });
});
