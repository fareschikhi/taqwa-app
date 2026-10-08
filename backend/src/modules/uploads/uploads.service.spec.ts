import { BadRequestException } from '@nestjs/common';
import { mkdtempSync, readFileSync, rmSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { UploadsService } from './uploads.service';

const PNG_BYTES = Buffer.from([
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x01,
]);

function fakeFile(mimetype: string, buffer: Buffer): Express.Multer.File {
  return { mimetype, buffer } as Express.Multer.File;
}

describe('UploadsService', () => {
  let dir: string;
  let service: UploadsService;

  beforeEach(() => {
    dir = mkdtempSync(join(tmpdir(), 'taqwa-uploads-'));
    process.env.UPLOAD_DIR = dir;
    service = new UploadsService();
    service.onModuleInit();
  });

  afterEach(() => {
    delete process.env.UPLOAD_DIR;
    rmSync(dir, { recursive: true, force: true });
  });

  it('writes the image to disk and returns its relative media path', async () => {
    const path = await service.uploadImage(fakeFile('image/png', PNG_BYTES));

    expect(path).toMatch(/^media\/[0-9a-f-]{36}\.png$/);
    const name = path.slice('media/'.length);
    expect(readFileSync(join(dir, name))).toEqual(PNG_BYTES);
  });

  it('gives every upload a distinct name', async () => {
    const a = await service.uploadImage(fakeFile('image/png', PNG_BYTES));
    const b = await service.uploadImage(fakeFile('image/png', PNG_BYTES));
    expect(a).not.toEqual(b);
  });

  it('rejects a file whose bytes do not match its declared image type', async () => {
    const html = Buffer.from('<script>alert(1)</script>');
    await expect(
      service.uploadImage(fakeFile('image/png', html)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
