import { Module } from '@nestjs/common';
import { JwtModule, JwtSignOptions } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthController } from './auth.controller';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { requireEnv } from '../../common/config/env';

@Module({
  imports: [
    PassportModule,
    // registerAsync, not register: this module is evaluated while app.module.ts
    // is still resolving its imports, so ConfigModule.forRoot() has not run yet
    // and process.env would still be empty. The factory runs later, at DI time.
    JwtModule.registerAsync({
      useFactory: () => ({
        secret: requireEnv('JWT_SECRET'),
        signOptions: {
          // Cast because JwtSignOptions types this as a `ms` template literal,
          // which an env string cannot satisfy statically.
          expiresIn: (process.env.JWT_EXPIRES_IN ??
            '7d') as JwtSignOptions['expiresIn'],
        },
      }),
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
