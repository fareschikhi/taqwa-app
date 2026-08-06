import { NotFoundException } from '@nestjs/common';
import { StudentsService } from './students.service';

describe('StudentsService.remove', () => {
  const makePrisma = (student: { id: number; userId: number } | null) => ({
    student: { findUnique: jest.fn().mockResolvedValue(student) },
    user: {
      delete: jest.fn().mockResolvedValue({ id: student?.userId }),
      update: jest.fn(),
    },
  });

  it('hard-deletes the linked user row', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await service.remove(7);

    expect(prisma.user.delete).toHaveBeenCalledWith({ where: { id: 42 } });
  });

  it('does not soft-delete by flipping isActive', async () => {
    const prisma = makePrisma({ id: 7, userId: 42 });
    const service = new StudentsService(prisma as any);

    await service.remove(7);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('throws NotFoundException when the student does not exist', async () => {
    const prisma = makePrisma(null);
    const service = new StudentsService(prisma as any);

    await expect(service.remove(7)).rejects.toBeInstanceOf(NotFoundException);
    expect(prisma.user.delete).not.toHaveBeenCalled();
  });
});
