import { Test } from '@nestjs/testing';
import { Module } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import request from 'supertest';
import {
  mediaStaticOptions,
  MEDIA_SEGMENT,
} from '../src/modules/uploads/upload-storage';

@Module({})
class EmptyModule {}

/**
 * Chat photos (doctor's notes, among others) live inside the public uploads
 * folder, in `.chat/`. Only the static server's dotfile refusal keeps them
 * private, so this pins that setting: a later change to the static options
 * that made them public fails here instead of leaking.
 */
describe('media static files', () => {
  let app: NestExpressApplication;
  let dir: string;

  beforeAll(async () => {
    dir = mkdtempSync(join(tmpdir(), 'taqwa-media-'));
    mkdirSync(join(dir, '.chat'));
    writeFileSync(join(dir, '.chat', 'secret.jpg'), 'x');
    writeFileSync(join(dir, 'avatar.jpg'), 'x');

    const moduleRef = await Test.createTestingModule({
      imports: [EmptyModule],
    }).compile();
    app = moduleRef.createNestApplication<NestExpressApplication>();
    app.useStaticAssets(dir, mediaStaticOptions());
    await app.init();
  });

  afterAll(async () => {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  });

  it('serves a public upload', async () => {
    await request(app.getHttpServer())
      .get(`/api/${MEDIA_SEGMENT}/avatar.jpg`)
      .expect(200);
  });

  it('refuses a chat photo', async () => {
    const res = await request(app.getHttpServer()).get(
      `/api/${MEDIA_SEGMENT}/.chat/secret.jpg`,
    );
    expect([403, 404]).toContain(res.status);
  });
});
