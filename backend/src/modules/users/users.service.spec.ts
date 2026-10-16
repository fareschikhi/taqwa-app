import { ConflictException } from '@nestjs/common';
import { UsersService } from './users.service';

/// `PATCH /users/me` lets a signed-in user edit their own account. Phone is
/// the login identifier and both phone and email are unique columns, so a
/// value already belonging to somebody else has to be refused before writing.
describe('UsersService.updateMe', () => {
  const makePrisma = (conflictingUser: { id: number } | null = null) => ({
    user: {
      findFirst: jest.fn().mockResolvedValue(conflictingUser),
      update: jest.fn().mockResolvedValue({ id: 7 }),
      findUnique: jest.fn().mockResolvedValue({ id: 7, fullName: 'x' }),
    },
  });

  it('writes the trimmed fields', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, {
      fullName: '  Ahmed Boudiaf  ',
      phone: ' 2001 ',
      email: ' a@b.test ',
    });

    const { data, where } = prisma.user.update.mock.calls[0][0];
    expect(where).toEqual({ id: 7 });
    expect(data.fullName).toBe('Ahmed Boudiaf');
    expect(data.phone).toBe('2001');
    expect(data.email).toBe('a@b.test');
  });

  it('rejects a phone that belongs to somebody else', async () => {
    const prisma = makePrisma({ id: 99 });
    const service = new UsersService(prisma as any);

    await expect(service.updateMe(7, { phone: '2001' })).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('rejects an email that belongs to somebody else', async () => {
    const prisma = makePrisma({ id: 99 });
    const service = new UsersService(prisma as any);

    await expect(
      service.updateMe(7, { email: 'taken@b.test' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('excludes the caller from the uniqueness check', async () => {
    // Saving your own unchanged phone must not collide with yourself.
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { phone: '2001' });

    const { where } = prisma.user.findFirst.mock.calls[0][0];
    expect(where.NOT).toEqual({ id: 7 });
  });

  it('clears the phone when given an empty string', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { phone: '   ' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data.phone).toBeNull();
    // An empty phone cannot collide, so no lookup is needed.
    expect(prisma.user.findFirst).not.toHaveBeenCalled();
  });

  it('leaves untouched fields alone', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { fullName: 'Only Name' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data).toEqual({ fullName: 'Only Name' });
  });
});

// A password an admin sets is a temporary one, except on an admin account:
// admins manage their own.
describe('UsersService passwords', () => {
  const makePrisma = (role = 'PARENT') => ({
    user: {
      create: jest.fn().mockResolvedValue({ id: 42 }),
      update: jest.fn().mockResolvedValue({ id: 42 }),
      findUnique: jest.fn().mockResolvedValue({ id: 42, role }),
    },
  });

  it('flags a new non-admin account', async () => {
    const prisma = makePrisma();

    await new UsersService(prisma as any).create({
      fullName: 'Karim Saidi',
      phone: '4200',
      password: 'secret123',
      role: 'PARENT',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('never flags a new admin account', async () => {
    const prisma = makePrisma();

    await new UsersService(prisma as any).create({
      fullName: 'Second Admin',
      phone: '4500',
      password: 'secret123',
      role: 'ADMIN',
    } as any);

    expect(prisma.user.create.mock.calls[0][0].data.mustChangePassword).toBe(
      false,
    );
  });

  it('flags a non-admin whose password an admin reset', async () => {
    const prisma = makePrisma('TEACHER');

    await new UsersService(prisma as any).update(42, {
      password: 'secret123',
    } as any);

    expect(prisma.user.update.mock.calls[0][0].data.mustChangePassword).toBe(
      true,
    );
  });

  it('never flags an admin whose password is reset', async () => {
    const prisma = makePrisma('ADMIN');

    await new UsersService(prisma as any).update(42, {
      password: 'secret123',
    } as any);

    expect(prisma.user.update.mock.calls[0][0].data.mustChangePassword).toBe(
      false,
    );
  });
});
