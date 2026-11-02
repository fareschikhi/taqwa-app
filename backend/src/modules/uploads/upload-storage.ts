import { join, resolve } from 'path';
import type { ServeStaticOptions } from '@nestjs/platform-express/interfaces/serve-static-options.interface';

/**
 * URL segment uploaded files are served under, relative to the API's global
 * `api` prefix. Stored avatars hold `media/<file>` rather than a full URL, so
 * moving the API to another host never breaks them.
 */
export const MEDIA_SEGMENT = 'media';

/**
 * Folder uploaded files are written to.
 *
 * Point UPLOAD_DIR at a persistent volume in production: in a container whose
 * disk is wiped on rebuild, everything in the default folder is lost with it.
 */
export function uploadDir(): string {
  return resolve(process.env.UPLOAD_DIR || 'uploads');
}

/**
 * Sub-folder of `uploadDir()` holding chat photos. The leading dot is what
 * keeps them private: the static server refuses dotfiles, so the only way to
 * a chat photo is the authorized `GET /chat/photos/:id` route. Staying inside
 * `uploadDir()` keeps them on the same persistent volume as everything else.
 */
export const CHAT_SEGMENT = '.chat';

export function chatUploadDir(): string {
  return join(uploadDir(), CHAT_SEGMENT);
}

/**
 * How `main.ts` serves public uploads. A function so a test can serve a
 * folder with exactly these options and prove `.chat/` stays refused.
 */
export function mediaStaticOptions(): ServeStaticOptions {
  return {
    prefix: `/api/${MEDIA_SEGMENT}/`,
    index: false,
    // Load-bearing: this is what refuses `.chat/`.
    dotfiles: 'deny',
    maxAge: '365d',
    immutable: true,
    setHeaders: (res) => res.setHeader('X-Content-Type-Options', 'nosniff'),
  };
}
