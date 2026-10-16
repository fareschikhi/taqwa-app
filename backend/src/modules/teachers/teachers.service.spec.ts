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
