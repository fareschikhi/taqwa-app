import { NestFactory } from '@nestjs/core';
import helmet from 'helmet';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { PrismaClientExceptionFilter } from './common/filters/prisma-client-exception.filter';
import { MEDIA_SEGMENT, uploadDir } from './modules/uploads/upload-storage';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // Tailscale Funnel forwards every request and names the real client in
  // X-Forwarded-For; without this each client would share the proxy's
  // address and the rate limits would throttle everyone at once.
  // Only private-network hops are trusted, so a client on the internet cannot
  // fake its address with its own X-Forwarded-For header.
  app.set('trust proxy', 'loopback, linklocal, uniquelocal');
  // Uploaded images are shown by the app from another origin; helmet's
  // default would block that in a browser build.
  app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
  app.enableCors();
  app.setGlobalPrefix('api');
  // Static assets bypass the global prefix, so it is spelled out here. Upload
  // names are random and never reused, which makes long caching safe.
  app.useStaticAssets(uploadDir(), {
    prefix: `/api/${MEDIA_SEGMENT}/`,
    index: false,
    dotfiles: 'deny',
    maxAge: '365d',
    immutable: true,
    setHeaders: (res) => res.setHeader('X-Content-Type-Options', 'nosniff'),
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  app.useGlobalFilters(new PrismaClientExceptionFilter());
  await app.listen(process.env.PORT ?? 3000, '0.0.0.0');
}
bootstrap();
