import { BadRequestException, Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { mkdirSync } from 'fs';
import { writeFile } from 'fs/promises';
import { join } from 'path';
import { MEDIA_SEGMENT, uploadDir } from './upload-storage';

/** File extension for each accepted type; the controller filters on these. */
const EXTENSIONS: Record<string, string> = {
  'image/jpeg': 'jpg',
  'image/png': 'png',
  'image/webp': 'webp',
};

/**
 * Saves uploaded images to the server's own disk.
 *
 * The files are served back from our own origin, so the client's declared
 * MIME type is not trusted on its own: the leading bytes must match it too.
 */
@Injectable()
export class UploadsService implements OnModuleInit {
  private dir!: string;

  /**
   * Create the folder at boot rather than on the first upload, so a path the
   * process cannot write to fails the deployment immediately.
   */
  onModuleInit() {
    this.dir = uploadDir();
    mkdirSync(this.dir, { recursive: true });
  }

  /**
   * Writes an in-memory file to disk and returns its path relative to the API
   * base URL, e.g. `media/3f2c….png`.
   */
  async uploadImage(file: Express.Multer.File): Promise<string> {
    const extension = EXTENSIONS[file.mimetype];
    if (!extension || !matchesSignature(file.buffer, file.mimetype)) {
      throw new BadRequestException('The file is not a valid image.');
    }

    // A random name, never the client's, so nobody can overwrite or guess
    // another user's photo.
    const name = `${randomUUID()}.${extension}`;
    await writeFile(join(this.dir, name), file.buffer);
    return `${MEDIA_SEGMENT}/${name}`;
  }
}

/** Checks the file's magic bytes against the type it claims to be. */
function matchesSignature(buffer: Buffer, mimetype: string): boolean {
  switch (mimetype) {
    case 'image/jpeg':
      return buffer.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]));
    case 'image/png':
      return buffer
        .subarray(0, 8)
        .equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    case 'image/webp':
      return (
        buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
        buffer.subarray(8, 12).toString('ascii') === 'WEBP'
      );
    default:
      return false;
  }
}
