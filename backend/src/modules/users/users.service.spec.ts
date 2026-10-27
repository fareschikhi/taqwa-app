import { UsersService } from './users.service';

/// `PATCH /users/me` lets a signed-in user edit their own account. Phone and
/// email may be shared with another account (one person can hold two), so the
/// values are written as given — the form only warns.
describe('UsersService.updateMe', () => {
  const makePrisma = () => ({
    user: {
      findFirst: jest.fn(),
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

  it('saves a phone or email another account already holds', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { phone: '2001', email: 'shared@b.test' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data.phone).toBe('2001');
    expect(data.email).toBe('shared@b.test');
    expect(prisma.user.findFirst).not.toHaveBeenCalled();
  });

  it('clears the phone when given an empty string', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { phone: '   ' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data.phone).toBeNull();
  });

  it('leaves untouched fields alone', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { fullName: 'Only Name' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data).toEqual({ fullName: 'Only Name' });
  });

  it('saves a newly uploaded avatar', async () => {
    const prisma = makePrisma();
    const service = new UsersService(prisma as any);

    await service.updateMe(7, { avatar: '/uploads/me.jpg' });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data).toEqual({ avatar: '/uploads/me.jpg' });
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

/// Feeds the "already used by …" hint under account forms' phone and email.
describe('UsersService.contactOwners', () => {
  const makePrisma = () => ({
    user: {
      findMany: jest
        .fn()
        .mockResolvedValue([{ id: 3, fullName: 'Karim Saidi', role: 'TEACHER' }]),
    },
  });

  it('names the accounts holding each value', async () => {
    const prisma = makePrisma();

    const result = await new UsersService(prisma as any).contactOwners({
      phone: ' 2001 ',
      email: 'a@b.test',
    });

    expect(result.phone).toEqual([
      { id: 3, fullName: 'Karim Saidi', role: 'TEACHER' },
    ]);
    expect(result.email).toHaveLength(1);
    expect(prisma.user.findMany.mock.calls[0][0].where.phone).toBe('2001');
  });

  it('leaves out the account being edited', async () => {
    const prisma = makePrisma();

    await new UsersService(prisma as any).contactOwners({
      phone: '2001',
      excludeUserId: 7,
    });

    expect(prisma.user.findMany.mock.calls[0][0].where.NOT).toEqual({ id: 7 });
  });

  it('looks nothing up for an empty value', async () => {
    const prisma = makePrisma();

    const result = await new UsersService(prisma as any).contactOwners({
      phone: '  ',
    });

    expect(result).toEqual({ phone: [], email: [] });
    expect(prisma.user.findMany).not.toHaveBeenCalled();
  });
});
