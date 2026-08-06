import { NotFoundException } from '@nestjs/common';
import { ParentsService } from './parents.service';

describe('ParentsService.remove', () => {
  const makePrisma = (parent: { id: number; userId: number } | null) => ({
    parent: { findUnique: jest.fn().mockResolvedValue(parent) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: parent?.userId }),
      update: jest.fn(),
    },
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 3, userId: 88 });
    const service = new ParentsService(prisma as any);

    await service.remove(3);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 88 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 3, userId: 88 });
    const service = new ParentsService(prisma as any);

    await service.remove(3);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('throws NotFoundException when the parent does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new ParentsService(prisma as any);

    await expect(service.remove(3)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});
