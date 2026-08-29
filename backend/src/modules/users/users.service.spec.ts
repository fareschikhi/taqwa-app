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
