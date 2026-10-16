import { resolve } from 'path';

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
