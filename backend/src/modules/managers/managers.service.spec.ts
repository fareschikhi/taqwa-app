import { NotFoundException } from '@nestjs/common';
import { ManagersService } from './managers.service';

describe('ManagersService.remove', () => {
  const makePrisma = (manager: { id: number; userId: number } | null) => ({
    manager: { findUnique: jest.fn().mockResolvedValue(manager) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: manager?.userId }),
      update: jest.fn(),
    },
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
