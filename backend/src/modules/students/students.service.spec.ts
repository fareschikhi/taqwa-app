import { NotFoundException, BadRequestException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';
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
  // A password alone means nothing: only isAdult turns a student into an
  // account, so a password arriving without it is ignored rather than
  // silently upgrading a child student into someone who can log in.
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

  it('creates a normal student as an account that cannot log in', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create(payload as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.role).toBe('STUDENT');
    expect(data.passwordHash).toBeNull();
  });

  it('creates an adult student with a usable password', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.create({
      ...payload,
      isAdult: true,
      password: 'secret123',
    } as any);

    const data = prisma.user.create.mock.calls[0][0].data;
    expect(data.role).toBe('ADULT_STUDENT');
    expect(await bcrypt.compare('secret123', data.passwordHash)).toBe(true);
  });

  // An adult student with no password is an account nobody can ever use, and
  // the form would have no way to tell the admin why he cannot sign in.
  it('refuses an adult student without a password', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await expect(
      service.create({ ...payload, isAdult: true } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
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

  // The overall rating is free text the teacher writes on the student profile,
  // so it belongs on the student row rather than the user account.
  it('persists a free-text currentRating on the student row', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { currentRating: 'ممتاز' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      currentRating: 'ممتاز',
    });
  });

  // Clearing the box is how a teacher retracts a rating, so an empty string has
  // to reach the database instead of being skipped as falsy.
  it('clears the rating when given an empty string', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { currentRating: '' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      currentRating: '',
    });
  });

  it('leaves the rating untouched when the field is absent', async () => {
    const prisma = makePrisma();
    const service = new StudentsService(prisma as any);

    await service.update(7, { address: 'Algiers' });

    expect(prisma.student.update.mock.calls[0][0].data).toEqual({
      address: 'Algiers',
    });
  });
});
