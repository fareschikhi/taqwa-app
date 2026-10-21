import {
  BadRequestException,
  ForbiddenException,
  HttpStatus,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { AuthService } from './auth.service';
import {
  LoginAttemptsService,
  MAX_FAILED_ATTEMPTS,
} from './login-attempts.service';

// A low cost keeps the suite fast; the hash is still a real bcrypt hash so the
// service's own `compare` call runs unmocked.
const PASSWORD = '123456';
const PASSWORD_HASH = bcrypt.hashSync(PASSWORD, 4);

const makeService = (user: Record<string, unknown> | null) => {
  const prisma = {
    user: { findMany: jest.fn().mockResolvedValue(user ? [user] : []) },
  };
  const jwt = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
  return new AuthService(
    prisma as any,
    jwt as unknown as JwtService,
    new LoginAttemptsService(),
  );
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
        findMany: jest.fn().mockResolvedValue([{
          id: 5,
          role: 'STUDENT',
          passwordHash: PASSWORD_HASH,
          student: { id: 3 },
        }]),
      },
    };
    const jwt = { sign: jest.fn().mockReturnValue('signed.jwt.token') };
    const service = new AuthService(
      prisma as any,
      jwt as unknown as JwtService,
      new LoginAttemptsService(),
    );

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

  // The app decides from this flag whether to hold the user on the
  // set-a-new-password screen, so it has to survive into the response.
  it('tells the client the password must be changed', async () => {
    const service = makeService({
      id: 9,
      fullName: 'Karim Saidi',
      phone: '4200',
      role: 'PARENT',
      passwordHash: PASSWORD_HASH,
      mustChangePassword: true,
      parent: { id: 4 },
    });

    const result = await service.login({
      phone: '4200',
      password: PASSWORD,
    } as any);

    expect(result.user.mustChangePassword).toBe(true);
  });

  // One person can hold two accounts on the same phone; the password is what
  // tells them apart.
  it('opens the shared-phone account the password belongs to', async () => {
    const teacher = {
      id: 12,
      fullName: 'Yacine Belkacem',
      phone: '4100',
      role: 'TEACHER',
      passwordHash: bcrypt.hashSync('teacher-pass', 4),
      teacher: { id: 2 },
    };
    const adult = {
      id: 11,
      fullName: 'Yacine Belkacem',
      phone: '4100',
      role: 'ADULT_STUDENT',
      passwordHash: PASSWORD_HASH,
      student: { id: 21 },
    };
    const prisma = {
      user: { findMany: jest.fn().mockResolvedValue([teacher, adult]) },
    };
    const service = new AuthService(
      prisma as any,
      { sign: jest.fn().mockReturnValue('t') } as unknown as JwtService,
      new LoginAttemptsService(),
    );

    const asTeacher = await service.login({
      phone: '4100',
      password: 'teacher-pass',
    } as any);
    const asStudent = await service.login({
      phone: '4100',
      password: PASSWORD,
    } as any);

    expect(asTeacher.user.role).toBe('TEACHER');
    expect(asStudent.user.role).toBe('ADULT_STUDENT');
  });

  // An empty `{}` inside OR would match every user in the table.
  it('filters only by the identifiers sent', async () => {
    const prisma = { user: { findMany: jest.fn().mockResolvedValue([]) } };
    const service = new AuthService(
      prisma as any,
      { sign: jest.fn() } as unknown as JwtService,
      new LoginAttemptsService(),
    );

    await expect(
      service.login({ phone: '4100', password: PASSWORD } as any),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    expect(prisma.user.findMany.mock.calls[0][0].where.OR).toEqual([
      { phone: '4100' },
    ]);
  });
});

describe('AuthService.changePassword', () => {
  const makeService = (
    user: Record<string, unknown> | null,
    siblings: Record<string, unknown>[] = [],
  ) => {
    const prisma = {
      user: {
        findUnique: jest.fn().mockResolvedValue(user),
        findMany: jest.fn().mockResolvedValue(siblings),
        update: jest.fn().mockResolvedValue({ id: 7 }),
      },
    };
    const jwt = { sign: jest.fn() };
    const service = new AuthService(
      prisma as any,
      jwt as unknown as JwtService,
      new LoginAttemptsService(),
    );
    return { service, prisma };
  };

  const active = { id: 7, role: 'ADMIN', passwordHash: PASSWORD_HASH };

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

  it('clears the must-change flag once the password is replaced', async () => {
    const { service, prisma } = makeService({
      id: 7,
      role: 'PARENT',
      passwordHash: PASSWORD_HASH,
      mustChangePassword: true,
    });

    await service.changePassword(7, {
      currentPassword: PASSWORD,
      newPassword: 'newpass1',
    });

    const { data } = prisma.user.update.mock.calls[0][0];
    expect(data.mustChangePassword).toBe(false);
  });

  it('refuses keeping the temporary password', async () => {
    const { service, prisma } = makeService({
      id: 7,
      role: 'PARENT',
      passwordHash: PASSWORD_HASH,
      mustChangePassword: true,
    });

    await expect(
      service.changePassword(7, {
        currentPassword: PASSWORD,
        newPassword: PASSWORD,
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });

  // Login tells shared-phone accounts apart by password alone.
  it('refuses a password the other account on the same phone uses', async () => {
    const { service, prisma } = makeService(
      {
        id: 7,
        role: 'ADULT_STUDENT',
        phone: '4100',
        passwordHash: PASSWORD_HASH,
        mustChangePassword: true,
      },
      [{ passwordHash: bcrypt.hashSync('teacher-pass', 4) }],
    );

    await expect(
      service.changePassword(7, {
        currentPassword: PASSWORD,
        newPassword: 'teacher-pass',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.user.update).not.toHaveBeenCalled();
    const { where } = prisma.user.findMany.mock.calls[0][0];
    expect(where.OR).toEqual([{ phone: '4100' }]);
    expect(where.NOT).toEqual({ id: 7 });
  });

  // Everyone but an admin has their password set by an admin; the one
  // exception is replacing the temporary password they were handed.
  it('refuses a non-admin whose password is not temporary', async () => {
    const { service, prisma } = makeService({
      id: 7,
      role: 'TEACHER',
      passwordHash: PASSWORD_HASH,
      mustChangePassword: false,
    });

    await expect(
      service.changePassword(7, {
        currentPassword: PASSWORD,
        newPassword: 'newpass1',
      }),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(prisma.user.update).not.toHaveBeenCalled();
  });
});

describe('AuthService.login lockout', () => {
  const parent = {
    id: 9,
    fullName: 'Karim Cherguini',
    phone: '3001',
    role: 'PARENT',
    passwordHash: PASSWORD_HASH,
    parent: { id: 4 },
  };

  const failTimes = async (service: AuthService, times: number) => {
    for (let i = 0; i < times; i++) {
      await expect(
        service.login({ phone: '3001', password: 'wrong-pass' } as any),
      ).rejects.toBeInstanceOf(UnauthorizedException);
    }
  };

  it('refuses even the right password once the account is locked', async () => {
    const service = makeService(parent);
    await failTimes(service, MAX_FAILED_ATTEMPTS);

    await expect(
      service.login({ phone: '3001', password: PASSWORD } as any),
    ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
  });

  it('forgets earlier failures after a successful sign-in', async () => {
    const service = makeService(parent);
    await failTimes(service, MAX_FAILED_ATTEMPTS - 1);
    await service.login({ phone: '3001', password: PASSWORD } as any);
    await failTimes(service, MAX_FAILED_ATTEMPTS - 1);

    const result = await service.login({
      phone: '3001',
      password: PASSWORD,
    } as any);
    expect(result.accessToken).toBe('signed.jwt.token');
  });

  // Otherwise the lock itself would reveal which phone numbers have accounts.
  it('locks an unknown identifier exactly like a real one', async () => {
    const service = makeService(null);
    await failTimes(service, MAX_FAILED_ATTEMPTS);

    await expect(
      service.login({ phone: '3001', password: 'wrong-pass' } as any),
    ).rejects.toMatchObject({ status: HttpStatus.TOO_MANY_REQUESTS });
  });
});
