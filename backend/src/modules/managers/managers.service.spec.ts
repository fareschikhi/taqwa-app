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
