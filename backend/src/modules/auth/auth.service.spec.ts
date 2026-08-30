import { UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';

// A low cost keeps the suite fast; the hash is still a real bcrypt hash so the
// service's own `compare` call runs unmocked.
const PASSWORD = '123456';
const PASSWORD_HASH = bcrypt.hashSync(PASSWORD, 4);

const makeService = (user: Record<string, unknown> | null) => {
  const prisma = { user: { findFirst: jest.fn().mockResolvedValue(user) } };
  const jwt = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
  return new AuthService(prisma as any, jwt as unknown as JwtService);
};

describe('AuthService.login', () => {
  it('rejects a STUDENT holding valid credentials', async () => {
    const service = makeService({
      id: 5,
      fullName: 'Bilal Cherguini',
      phone: '4008',
      role: 'STUDENT',
      passwordHash: PASSWORD_HASH,
      student: { id: 3 },
    });

    await expect(
      service.login({ phone: '4008', password: PASSWORD } as any),
    ).rejects.toBeInstanceOf(UnauthorizedException);
  });

  it('does not issue a token to a STUDENT', async () => {
    const prisma = {
      user: {
        findFirst: jest.fn().mockResolvedValue({
          id: 5,
          role: 'STUDENT',
          passwordHash: PASSWORD_HASH,
          student: { id: 3 },
        }),
      },
    };
    const jwt = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    const service = new AuthService(prisma as any, jwt as unknown as JwtService);

    await expect(
      service.login({ phone: '4008', password: PASSWORD } as any),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(jwt.sign).not.toHaveBeenCalled();
  });

  it('signs in an ADULT_STUDENT with valid credentials', async () => {
    const service = makeService({
      id: 11,
      fullName: 'Yacine Belkacem',
      phone: '4100',
      role: 'ADULT_STUDENT',
      passwordHash: PASSWORD_HASH,
      student: { id: 21 },
    });

    const result = await service.login({
      phone: '4100',
      password: PASSWORD,
    } as any);

    expect(result.accessToken).toBe('signed.jwt.token');
  });

  // The whole adult-student feature hangs off this id reaching the client:
  // it is how the app knows which student record to show him.
  it('returns the adult student their own student id', async () => {
    const service = makeService({
      id: 11,
      fullName: 'Yacine Belkacem',
      phone: '4100',
      role: 'ADULT_STUDENT',
      passwordHash: PASSWORD_HASH,
      student: { id: 21 },
    });

    const result = await service.login({
      phone: '4100',
      password: PASSWORD,
    } as any);

    expect(result.user.student).toEqual({ id: 21 });
  });

  it('still signs in a PARENT with valid credentials', async () => {
    const service = makeService({
      id: 9,
      fullName: 'Karim Cherguini',
      phone: '3001',
      role: 'PARENT',
      passwordHash: PASSWORD_HASH,
      parent: { id: 4 },
    });

    const result = await service.login({
      phone: '3001',
      password: PASSWORD,
    } as any);

    expect(result.accessToken).toBe('signed.jwt.token');
    expect(result.user.role).toBe('PARENT');
  });
});

describe('AuthService.changePassword', () => {
  const makeService = (user: Record<string, unknown> | null) => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(user),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
    };
    const jwt = { sign: jest.fn() };
    const service = new AuthService(prisma as any, jwt as unknown as JwtService);
    return { service, prisma };
  };

  const active = { id: 7, passwordHash: PASSWORD_HASH };

  it('rejects a wrong current password', async () => {
    const { service, prisma } = makeService(active);

    await expect(
      service.changePassword(7, {
        currentPassword: 'not-it',
        newPassword: 'newpass1',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('rejects a user holding no password hash', async () => {
    const { service, prisma } = makeService({ id: 7, passwordHash: null });

    await expect(
      service.changePassword(7, {
        currentPassword: PASSWORD,
        newPassword: 'newpass1',
      }),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  it('stores a hash the new password verifies against', async () => {
    const { service, prisma } = makeService(active);

    await service.changePassword(7, {
      currentPassword: PASSWORD,
      newPassword: 'newpass1',
    });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(await bcrypt.compare('newpass1', data.passwordHash)).toBe(true);
  });

  it('never stores the new password in the clear', async () => {
    const { service, prisma } = makeService(active);

    await service.changePassword(7, {
      currentPassword: PASSWORD,
      newPassword: 'newpass1',
    });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data.passwordHash).not.toBe('newpass1');
  });
});
