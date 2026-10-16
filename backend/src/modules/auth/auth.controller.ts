import { Body, Controller, Patch, Post, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { AuthService } from './auth.service';
import { LoginDto } from './dto/login.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
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

  // Open to every role at the guard, but the service refuses anyone other
  // than an admin unless their password is a temporary one an admin set: an
  // administrator sets everybody else's password through the per-role forms,
  // which is also what the login screen's forgot-password dialog tells users
  // to expect. The id comes from the token, so this only ever changes one's own.
  @Patch('password')
  @Throttle({ default: { limit: 5, ttl: 60_000 } })
  @UseGuards(JwtAuthGuard)
  changePassword(@CurrentUser() user: any, @Body() dto: ChangePasswordDto) {
    return this.authService.changePassword(user.id, dto);
  }
}
