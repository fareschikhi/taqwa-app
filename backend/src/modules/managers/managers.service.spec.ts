jest.mock('../points/day-points', () => ({
  reconcileDayPoints: jest.fn().mockResolvedValue(undefined),
}));
import { ConflictException, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { reconcileDayPoints } from '../points/day-points';
import { ManagersService } from './managers.service';

describe('ManagersService.remove', () => {
  const makePrisma = (
    manager: { id: number; userId: number } | null,
    excused: Array<{ attendance: { studentId: number; date: Date } }> = [],
  ) => {
    const prisma: any = {
      manager: { findUnique: jest.fn().mockResolvedValue(manager) },
      user: {
        delete: jest.fn().mockResolvedValue({ id: manager?.userId }),
        update: jest.fn(),
      },
      absenceJustification: { findMany: jest.fn().mockResolvedValue(excused) },
    };
    prisma.$transaction = jest.fn((cb: any) => cb(prisma));
    return prisma;
  };

  // The cascade takes the manager's excuses with it, so each excused day is
  // an unexcused absence again and its points must say so.
  it('re-reconciles every day the manager had excused', async () => {
    const points = jest.mocked(reconcileDayPoints);
    points.mockClear();
    const d1 = new Date('2026-11-05');
    const d2 = new Date('2026-11-06');
    const prisma = makePrisma({ id: 2, userId: 64 }, [
      { attendance: { studentId: 7, date: d1 } },
      { attendance: { studentId: 8, date: d2 } },
    ]);

    await new ManagersService(prisma).remove(2);

    expect(prisma.absenceJustification.findMany).toHaveBeenCalledWith({
      where: { managerId: 2 },
      select: { attendance: { select: { studentId: true, date: true } } },
    });
    expect(points).toHaveBeenCalledWith(prisma, 7, d1);
    expect(points).toHaveBeenCalledWith(prisma, 8, d2);
    expect(points.mock.invocationCallOrder[0]).toBeGreaterThan(
      prisma.user.delete.mock.invocationCallOrder[0],
    );
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 2, userId: 64 });
    const service = new ManagersService(prisma as any);

    await service.remove(2);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 64 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 2, userId: 64 });
    const service = new ManagersService(prisma as any);

    await service.remove(2);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

// Points, fines and announcements keep their author (onDelete: Restrict),
  // so an account that made any of them cannot be hard-deleted. The admin
  // must get a sentence, not Prisma's English error text.
  it('explains in Arabic when the account still has records', async () => {
    const prisma = makePrisma({ id: 2, userId: 64 });
    prisma.user.delete.mockRejectedValue(
      new Prisma.PrismaClientKnownRequestError('Foreign key constraint violated', {
        code: 'P2003',
        clientVersion: 'test',
      }),
    );

    const err = await new ManagersService(prisma as any).remove(2).catch((e) => e);

    expect(err).toBeInstanceOf(ConflictException);
    expect(err.message).toBe(
      'لا يمكن حذف هذا الحساب لأن له سجلات مرتبطة (نقاط أو غرامات أو إعلانات). عطّل الحساب بدلاً من ذلك.',
    );
  });

  it('throws NotFoundException when the manager does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new ManagersService(prisma as any);

    await expect(service.remove(2)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});

// A password an admin sets is a temporary one: the manager replaces it on
// their next login.
describe('ManagersService passwords', () => {
  const makePrisma = () => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42 }),
      update: jest.fn().mockResolvedValue({ id: 42 }),
    },
    manager: { findUnique: jest.fn().mockResolvedValue({ id: 3, userId: 42 }) },
  });

  const makeService = (prisma: ReturnType<typeof makePrisma>) => {
    const service = new ManagersService(prisma as any);
    jest.spyOn(service, 'findOne').mockResolvedValue({} as any);
    return service;
  };

  it('makes a new manager change the password on first login', async () => {
    const prisma = makePrisma();

    await makeService(prisma).create({
      fullName: 'Nadir Hamdi',
      phone: '4300',
      password: 'secret123',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('makes the manager change a password an admin reset', async () => {
    const prisma = makePrisma();

    await makeService(prisma).update(3, { password: 'secret123' } as any);

    expect(prisma.user.update.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('leaves the flag alone when the password is not touched', async () => {
    const prisma = makePrisma();

    await makeService(prisma).update(3, { fullName: 'Nadir H.' } as any);

    expect(prisma.user.update.mock.calls[0][0].data).not.toHaveProperty(
      'mustChangePassword',
    );
  });
});

// Students outside every halaqa have no ManagerHalaqa row, so a manager
// reaches them only through the canAccessUnassigned flag.
describe('ManagersService unassigned students', () => {
  const makePrisma = (canAccessUnassigned: boolean) => ({
    manager: {
      findUnique: jest.fn().mockResolvedValue({
        id: 3,
        userId: 42,
        canAccessUnassigned,
        halaqas: [{ halaqaId: 5 }],
      }),
      update: jest.fn(),
    },
    user: { create: jest.fn(), update: jest.fn() },
    student: { findMany: jest.fn().mockResolvedValue([]) },
  });

  it('adds the unassigned students when the flag is on', async () => {
    const prisma = makePrisma(true);

    await new ManagersService(prisma as any).getStudents(3);

    expect(prisma.student.findMany.mock.calls[0][0].where).toEqual({
      OR: [{ halaqaId: { in: [5] } }, { halaqaId: null }],
    });
  });

  it('keeps to the assigned halaqas when the flag is off', async () => {
    const prisma = makePrisma(false);

    await new ManagersService(prisma as any).getStudents(3);

    expect(prisma.student.findMany.mock.calls[0][0].where).toEqual({
      OR: [{ halaqaId: { in: [5] } }],
    });
  });

  it('stores the flag when a manager is created', async () => {
    const prisma = makePrisma(false);

    await new ManagersService(prisma as any).create({
      fullName: 'Nadir Hamdi',
      password: 'secret123',
      canAccessUnassigned: true,
    } as any);

    expect(
      prisma.user.create.mock.calls[0][0].data.manager.create
        .canAccessUnassigned,
    ).toBe(true);
  });

  it('updates the flag on its own', async () => {
    const prisma = makePrisma(false);
    const service = new ManagersService(prisma as any);
    jest.spyOn(service, 'findOne').mockResolvedValue({} as any);

    await service.update(3, { canAccessUnassigned: true } as any);

    expect(prisma.manager.update).toHaveBeenCalledWith({
      where: { id: 3 },
      data: { canAccessUnassigned: true },
    });
  });
});

// The admin grants chat per manager, the same way as the other privileges.
describe('ManagersService chat privilege', () => {
  const makePrisma = () => ({
    manager: {
      findUnique: jest.fn().mockResolvedValue({ id: 3, userId: 42 }),
      update: jest.fn(),
    },
    user: { create: jest.fn(), update: jest.fn() },
  });

  it('create defaults canChat to false', async () => {
    const prisma = makePrisma();

    await new ManagersService(prisma as any).create({
      fullName: 'Nadir Hamdi',
      password: 'secret123',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.manager.create.canChat).toBe(
      false,
    );
  });

  it('update writes canChat when given', async () => {
    const prisma = makePrisma();
    const service = new ManagersService(prisma as any);
    jest.spyOn(service, 'findOne').mockResolvedValue({} as any);

    await service.update(3, { canChat: true } as any);

    expect(prisma.manager.update).toHaveBeenCalledWith({
      where: { id: 3 },
      data: { canChat: true },
    });
  });
});
