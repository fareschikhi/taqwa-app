import { BadRequestException } from '@nestjs/common';
import {
  existsSync,
  mkdtempSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { ChatPhotos } from './chat-photos';

const JPEG = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);

const file = (mimetype: string, buffer: Buffer) =>
  ({ mimetype, buffer }) as Express.Multer.File;

describe('ChatPhotos', () => {
  let dir: string;
  let photos: ChatPhotos;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'taqwa-chat-'));
    process.env.UPLOAD_DIR = dir;
    photos = new ChatPhotos();
    photos.onModuleInit();
  });

  afterEach(() => {
    delete process.env.UPLOAD_DIR;
    rmSync(dir, { recursive: true, force: true });
  });

  it('saves a real image under .chat with a random name', async () => {
    const path = await photos.save(file('image/jpeg', JPEG));

    expect(path).toMatch(/^\.chat\/[0-9a-f-]{36}\.jpg$/);
    expect(existsSync(join(dir, path))).toBe(true);
  });

  it('rejects a file whose bytes are not the image it claims, writing nothing', async () => {
    await expect(
      photos.save(file('image/jpeg', Buffer.from('MZ this is an exe'))),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(readdirSync(join(dir, '.chat'))).toEqual([]);
  });

  it('deletes a stored photo', async () => {
    const path = await photos.save(file('image/jpeg', JPEG));

    await photos.deleteChatPhoto(path);

    expect(existsSync(join(dir, path))).toBe(false);
  });

  it('ignores a photo that is already gone', async () => {
    await expect(
      photos.deleteChatPhoto('.chat/00000000-0000-0000-0000-000000000000.jpg'),
    ).resolves.toBeUndefined();
  });

  // The stored path comes from our own database, but a path that escapes the
  // folder must never become a file the server reads or deletes.
  it('refuses a path outside .chat', async () => {
    writeFileSync(join(dir, 'avatar.jpg'), 'x');

    expect(() => photos.absolutePath('.chat/../avatar.jpg')).toThrow();
    await photos.deleteChatPhoto('../avatar.jpg');
    expect(existsSync(join(dir, 'avatar.jpg'))).toBe(true);
  });
});
