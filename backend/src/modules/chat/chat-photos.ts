import { BadRequestException, Injectable, OnModuleInit } from '@nestjs/common';
import { randomUUID } from 'crypto';
import type { Response } from 'express';
import { mkdirSync } from 'fs';
import { unlink, writeFile } from 'fs/promises';
import { join } from 'path';
import {
  CHAT_SEGMENT,
  chatUploadDir,
  uploadDir,
} from '../uploads/upload-storage';
import { EXTENSIONS, matchesSignature } from '../uploads/uploads.service';

/** The only shape a stored chat photo path may have. */
const STORED_PATH = /^\.chat\/[0-9a-f-]{36}\.(jpg|png|webp)$/;

/**
 * Private storage for chat photos (see CHAT_SEGMENT for why it is private).
 *
 * Paths are stored relative to `uploadDir()`, like avatars, so moving the
 * folder never breaks them; unlike avatars they are only ever read back
 * through an authorized route.
 */
@Injectable()
export class ChatPhotos implements OnModuleInit {
  /** Fails the boot, not the first upload, when the folder isn't writable. */
  onModuleInit() {
    mkdirSync(chatUploadDir(), { recursive: true });
  }

  /** Writes a checked image and returns its stored path, `.chat/<uuid>.<ext>`. */
  async save(file: Express.Multer.File): Promise<string> {
    const extension = EXTENSIONS[file.mimetype];
    if (!extension || !matchesSignature(file.buffer, file.mimetype)) {
      throw new BadRequestException('الملف ليس صورة صالحة');
    }
    const path = `${CHAT_SEGMENT}/${randomUUID()}.${extension}`;
    await writeFile(join(uploadDir(), path), file.buffer);
    return path;
  }

  /** The file on disk for a stored path; throws for anything malformed. */
  absolutePath(path: string): string {
    if (!STORED_PATH.test(path)) throw new BadRequestException('مسار غير صالح');
    return join(uploadDir(), path);
  }

  /** Streams a stored photo to an already-authorized caller. */
  serve(res: Response, path: string): void {
    res.setHeader('Cache-Control', 'private, max-age=86400');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    // sendFile 404s any path with a dot segment unless told otherwise, and
    // `.chat` is one. Safe to allow: absolutePath only accepts STORED_PATH.
    res.sendFile(this.absolutePath(path), { dotfiles: 'allow' });
  }

  /** Best effort: a file that is already gone is not an error. */
  async deleteChatPhoto(path: string): Promise<void> {
    if (!STORED_PATH.test(path)) return;
    try {
      await unlink(join(uploadDir(), path));
    } catch (e) {
      if ((e as NodeJS.ErrnoException).code !== 'ENOENT') throw e;
    }
  }
}
