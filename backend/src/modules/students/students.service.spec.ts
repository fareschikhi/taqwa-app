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

describe('StudentsService.create', () => {
  // Students are records, not accounts: `password` is gone from the DTO, but a
  // stale client can still put one on the wire, so the service must ignore it.
  const makePrisma = () => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42, student: { id: 7 } }),
    },
    student: { findUnique: jest.fn().mockResolvedValue({ id: 7 }) },
  });

  const payload = {
    fullName: 'Bilal Cherguini',
    phone: '4008',
    address: 'الجزائر العاصمة',
    birthDate: '2012-05-01',
  };

  it('stores no password hash for a new student', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.passwordHash).toBeNull();
  });

  it('ignores a password a stale client still sends', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({ ...payload, password: 'hunter2' } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.passwordHash).toBeNull();
  });
});

describe('StudentsService.update', () => {
  const makePrisma = () => ({
    student: {
      findUnique: jest.fn().mockResolvedValue({ id: 7, userId: 42 }),
      update: jest.fn().mockResolvedValue({ id: 7 }),
    },
    user: { update: jest.fn(), findFirst: jest.fn() },
  });

  it('ignores a password a stale client still sends', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { password: 'hunter2' } as any);

    expect(prisma.user.update).not.toHaveBeenCalled();
  });
});
