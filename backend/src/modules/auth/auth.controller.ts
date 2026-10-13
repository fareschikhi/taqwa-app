import { Body, Controller, Patch, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  // Per IP, on top of the per-account lock in AuthService. Loose enough for a
  // family or a mosque sharing one address, tight enough to stop a guesser.
  @Post('login')
  @Throttle({ default: { limit: 10, ttl: 60_000 } })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  // ADMIN-only, like the rest of the account changes: an administrator sets
  // everybody else's password through the per-role forms, which is also what
  // the login screen's forgot-password dialog tells users to expect. The id
  // still comes from the token, so this only ever changes the admin's own.
  @Patch('password')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @Roles(Role.ADMIN)
  @UseGuards(JwtAuthGuard, RolesGuard)
  changePassword(@CurrentUser() user: any, @Body() dto: ChangePasswordDto) {
    return this.authService.changePassword(user.id, dto);
  }
}
