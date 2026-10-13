import {
  Injectable,
  UnauthorizedException,
  BadRequestException,
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

@Injectable()
export class AuthService {
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

    const user = await this.prisma.user.findFirst({
      where: {
        OR: [
          dto.email ? { email: dto.email } : {},
          dto.phone ? { phone: dto.phone } : {},
        ],
        isActive: true,
      },
      include: {
        student: { select: { id: true } },
        parent: { select: { id: true } },
        teacher: { select: { id: true } },
        manager: {
          select: {
            id: true,
            canManageAccounts: true,
            canDeleteAccounts: true,
          },
        },
      },
    });

    // Students are records in Taqwa, not accounts — no screen exists for a
    // child to log into. An adult student is the exception: he is his own
    // guardian, so his account is real. Every refusal below shares one
    // message and runs one bcrypt compare, so a probe cannot tell a blocked
    // or missing account apart from a wrong password.
    const hash = user?.role !== 'STUDENT' ? user?.passwordHash : null;
    const valid = await bcrypt.compare(
      dto.password,
      hash ?? DUMMY_PASSWORD_HASH,
    );
    if (!user || !hash || !valid) {
      this.loginAttempts.recordFailure(attemptKeys);
      throw new UnauthorizedException('بيانات الدخول غير صحيحة');
    }
    this.loginAttempts.recordSuccess(attemptKeys);

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
        student: user.student ? { id: user.student.id } : undefined,
        parent: user.parent ? { id: user.parent.id } : undefined,
        teacher: user.teacher ? { id: user.teacher.id } : undefined,
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

    const valid = await bcrypt.compare(dto.currentPassword, user.passwordHash);
    if (!valid) {
      throw new UnauthorizedException('كلمة المرور الحالية غير صحيحة');
    }

    await this.prisma.user.update({
      where: { id: userId },
      data: { passwordHash: await bcrypt.hash(dto.newPassword, 10) },
    });

    // The token deliberately survives: changing your own password on the
    // device in your hand is not a request to be logged out of it.
    return { success: true as const };
  }

  async validateUser(userId: number) {
    return this.prisma.user.findUnique({
      where: { id: userId, isActive: true },
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        role: true,
        avatar: true,
        student: { select: { id: true } },
        parent: { select: { id: true } },
        teacher: { select: { id: true } },
        manager: {
          select: {
            id: true,
            canManageAccounts: true,
            canDeleteAccounts: true,
          },
        },
      },
    });
  }
}
