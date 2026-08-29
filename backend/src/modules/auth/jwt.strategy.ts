import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { AuthService } from './auth.service';
import { requireEnv } from '../../common/config/env';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(private authService: AuthService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: requireEnv('JWT_SECRET'),
    });
  }

  async validate(payload: { sub: number; role: string; exp: number }) {
    const user = await this.authService.validateUser(payload.sub);
    // `exp` is present at runtime whenever signOptions sets expiresIn; the
    // TokenRefreshInterceptor needs it to decide whether to re-sign.
    return user ? { ...user, tokenExp: payload.exp } : null;
  }
}
