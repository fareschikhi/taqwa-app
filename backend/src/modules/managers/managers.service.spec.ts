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
