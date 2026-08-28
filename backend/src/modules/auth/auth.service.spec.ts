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
