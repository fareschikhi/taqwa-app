import {
  CallHandler,
  ExecutionContext,
  Injectable,
  NestInterceptor,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Observable } from 'rxjs';
import { tap } from 'rxjs/operators';

/**
 * Hands back a fresh token before the current one runs out, so an active user
 * is never signed out mid-use.
 *
 * There is no refresh-token table because AuthService.validateUser re-reads
 * `{ id, isActive: true }` on every request — deactivating an account already
 * revokes it immediately, which is the main thing such a table would buy.
 */
const REFRESH_WHEN_REMAINING_SECONDS = 7 * 24 * 60 * 60;

@Injectable()
export class TokenRefreshInterceptor implements NestInterceptor {
  constructor(private jwtService: JwtService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    return next.handle().pipe(
      tap(() => {
        const http = context.switchToHttp();
        const user = http.getRequest().user;
        if (!user?.tokenExp) return;

        const remaining = user.tokenExp - Math.floor(Date.now() / 1000);
        if (remaining > REFRESH_WHEN_REMAINING_SECONDS) return;

        http
          .getResponse()
          .header(
            'X-Refreshed-Token',
            this.jwtService.sign({ sub: user.id, role: user.role }),
          );
      }),
    );
  }
}
