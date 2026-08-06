import { NotFoundException } from '@nestjs/common';
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

  it('throws NotFoundException when the teacher does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new TeachersService(prisma as any);

    await expect(service.remove(5)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});
