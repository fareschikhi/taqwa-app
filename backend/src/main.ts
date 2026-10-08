import { NestFactory } from '@nestjs/core';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';
import { ValidationPipe } from '@nestjs/common';
import { PrismaClientExceptionFilter } from './common/filters/prisma-client-exception.filter';
import { MEDIA_SEGMENT, uploadDir } from './modules/uploads/upload-storage';

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
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
