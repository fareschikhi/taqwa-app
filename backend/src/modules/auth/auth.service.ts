import {
  Injectable,
  Logger,
  UnauthorizedException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../../prisma/prisma.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import * as bcrypt from 'bcrypt';
import { LoginAttemptsService } from './login-attempts.service';

/**
 * Compared against when no account matches, so a miss takes as long as a
 * wrong password and response times do not reveal which accounts exist.
 */
const DUMMY_PASSWORD_HASH = bcrypt.hashSync('taqwa-no-such-account', 10);

/**
 * How stale `lastSeenAt` may get before a request refreshes it. Staff read it
 * in days ("seen 3 days ago"), so minutes of slack cost nothing, while writing
 * on every request would mean an UPDATE per API call.
 */
export const LAST_SEEN_THROTTLE_MS = 10 * 60 * 1000;

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private prisma: PrismaService,
    private jwtService: JwtService,
    private loginAttempts: LoginAttemptsService,
  ) {}

  async login(dto: LoginDto) {
    if (!dto.email && !dto.phone) {
      throw new BadRequestException(
        'يجب توفير البريد الإلكتروني أو رقم الهاتف',
      );
    }

    // MySQL compares emails case-insensitively, so the key does too.
    const attemptKeys = [
      ...(dto.email ? [`email:${dto.email.toLowerCase()}`] : []),
      ...(dto.phone ? [`phone:${dto.phone}`] : []),
    ];
    this.loginAttempts.assertNotLocked(attemptKeys);

    // Phone and email are not unique: one person can hold two accounts (a
    // teacher who is also an adult student), so every holder is a candidate
    // and the password picks between them. Only the identifiers actually sent
    // go into the filter — an empty `{}` in OR would match every user.
    const identifiers = [
      ...(dto.email ? [{ email: dto.email }] : []),
      ...(dto.phone ? [{ phone: dto.phone }] : []),
    ];
    const candidates = await this.prisma.user.findMany({
      where: { OR: identifiers, isActive: true },
      // A temporary password first: if an admin's reset happens to equal the
      // sibling account's password, the account waiting for it is the one
      // meant. Its holder must then pick a password the sibling does not use.
      orderBy: [{ mustChangePassword: 'desc' }, { id: 'asc' }],
      include: {
        student: { select: { id: true } },
        parent: { select: { id: true } },
        teacher: { select: { id: true, canPostNews: true } },
        manager: {
          select: {
            id: true,
            canManageAccounts: true,
            canDeleteAccounts: true,
            canChat: true,
            canAccessUnassigned: true,
          },
        },
      },
    });

    // Students are records in Taqwa, not accounts — no screen exists for a
    // child to log into. An adult student is the exception: he is his own
    // guardian, so his account is real. Every refusal below shares one
    // message, and with no account able to log in one bcrypt compare still
    // runs, so a probe cannot tell a blocked or missing account apart from a
    // wrong password.
    const loginable = candidates.filter(
      (c) => c.role !== 'STUDENT' && c.passwordHash,
    );
    let user: (typeof candidates)[number] | undefined;
    for (const candidate of loginable) {
      if (await bcrypt.compare(dto.password, candidate.passwordHash!)) {
        user = candidate;
        break;
      }
    }
    if (loginable.length === 0) {
      await bcrypt.compare(dto.password, DUMMY_PASSWORD_HASH);
    }
    if (!user) {
      this.loginAttempts.recordFailure(attemptKeys);
      throw new UnauthorizedException('بيانات الدخول غير صحيحة');
    }
    this.loginAttempts.recordSuccess(attemptKeys);
    await this.stampLogin(user.id);

    const payload = { sub: user.id, role: user.role };
    const token = this.jwtService.sign(payload);

    return {
      accessToken: token,
      user: {
        id: user.id,
        fullName: user.fullName,
        email: user.email,
        phone: user.phone,
        role: user.role,
        avatar: user.avatar,
        mustChangePassword: user.mustChangePassword,
        student: user.student ? { id: user.student.id } : undefined,
        parent: user.parent ? { id: user.parent.id } : undefined,
        teacher: user.teacher ?? undefined,
        manager: user.manager ?? undefined,
      },
    };
  }

  async changePassword(userId: number, dto: ChangePasswordDto) {
    const user = await this.prisma.user.findUnique({ where: { id: userId } });

    // A missing user or an empty hash gets the same message as a wrong
    // password: nothing here should help someone probe an account.
    if (!user?.passwordHash) {
      throw new UnauthorizedException('كلمة المرور الحالية غير صحيحة');
    }

    // Everyone but an admin has their password set by an admin. The one
    // exception is replacing the temporary password they were handed.
    if (user.role !== 'ADMIN' && !user.mustChangePassword) {
      throw new ForbiddenException('تغيير كلمة المرور يتم عن طريق الإدارة');
    }

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('كلمة المرور الحالية غير صحيحة');
    }

    if (dto.newPassword === dto.currentPassword) {
      throw new BadRequestException(
        'كلمة المرور الجديدة يجب أن تختلف عن الحالية',
      );
    }

    // Login tells accounts that share a phone or email apart by password
    // alone, so a password one of them already uses would hide the other.
    const shared = [
      ...(user.phone ? [{ phone: user.phone }] : []),
      ...(user.email ? [{ email: user.email }] : []),
    ];
    if (shared.length > 0) {
      const siblings = await this.prisma.user.findMany({
        where: { OR: shared, NOT: { id: userId }, passwordHash: { not: null } },
        select: { passwordHash: true },
      });
      for (const sibling of siblings) {
        if (await bcrypt.compare(dto.newPassword, sibling.passwordHash!)) {
          throw new BadRequestException(
            'كلمة المرور هذه مستخدمة في حساب آخر بنفس رقم الهاتف أو البريد الإلكتروني، اختر كلمة مرور مختلفة',
          );
        }
      }
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: {
        passwordHash: await bcrypt.hash(dto.newPassword, 10),
        mustChangePassword: false,
      },
    });

    // The token deliberately survives: changing your own password on the
    // device in your hand is not a request to be logged out of it.
    return { success: true as const };
  }

  async validateUser(userId: number) {
    const found = await this.prisma.user.findUnique({
      where: { id: userId, isActive: true },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        avatar: true,
        mustChangePassword: true,
        lastSeenAt: true,
        student: { select: { id: true } },
        parent: { select: { id: true } },
        teacher: { select: { id: true, canPostNews: true } },
        manager: {
          select: {
            id: true,
            canManageAccounts: true,
            canDeleteAccounts: true,
            canChat: true,
            canAccessUnassigned: true,
          },
        },
      },
    });
    if (!found) return null;

    // Every authenticated request passes through here, so this is where
    // "still uses the app" is noticed — a parent whose token keeps being
    // refreshed never logs in again. Not awaited: the request must not wait
    // on bookkeeping.
    const { lastSeenAt, ...user } = found;
    void this.touchLastSeen(user.id, lastSeenAt);
    return user;
  }

  private async stampLogin(userId: number) {
    const now = new Date();
    try {
      await this.prisma.user.update({
        where: { id: userId },
        data: { lastLoginAt: now, lastSeenAt: now },
      });
    } catch (e) {
      // Bookkeeping only: a failed stamp must never lock a parent out.
      this.logger.warn(`lastLoginAt stamp failed: ${(e as Error).name}`);
    }
  }

  private async touchLastSeen(userId: number, lastSeenAt: Date | null) {
    const now = Date.now();
    const cutoff = new Date(now - LAST_SEEN_THROTTLE_MS);
    if (lastSeenAt && lastSeenAt >= cutoff) return;
    try {
      // The condition is repeated in the WHERE so two requests landing
      // together write once, not twice: the second matches no row.
      await this.prisma.user.updateMany({
        where: {
          id: userId,
          OR: [{ lastSeenAt: null }, { lastSeenAt: { lt: cutoff } }],
        },
        data: { lastSeenAt: new Date(now) },
      });
    } catch (e) {
      this.logger.warn(`lastSeenAt stamp failed: ${(e as Error).name}`);
    }
  }
}
