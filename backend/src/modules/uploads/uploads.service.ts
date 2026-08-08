import {
  Injectable,
  InternalServerErrorException,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';
import { requireEnv } from '../../common/config/env';

/** Where avatars land inside the Cloudinary media library. */
const AVATAR_FOLDER = 'taqwa/avatars';

/**
 * Uploads images to Cloudinary on the server's behalf.
 *
 * The API secret lives here and only here: signing used to happen in the
 * Flutter client, which meant shipping the secret to every device.
 */
@Injectable()
export class UploadsService implements OnModuleInit {
  private readonly logger = new Logger(UploadsService.name);

  /**
   * Fail at boot rather than on the first upload, so a half-configured
   * deployment is obvious immediately.
   */
  onModuleInit() {
    cloudinary.config({
      cloud_name: requireEnv('CLOUDINARY_CLOUD_NAME'),
      api_key: requireEnv('CLOUDINARY_API_KEY'),
      api_secret: requireEnv('CLOUDINARY_API_SECRET'),
    });
  }

  /**
   * Streams an in-memory file to Cloudinary and returns its public URL.
   *
   * `upload_stream` takes a callback rather than returning a promise, hence
   * the manual wrapping.
   */
  async uploadImage(file: Express.Multer.File): Promise<string> {
    const result = await new Promise<UploadApiResponse>((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        { folder: AVATAR_FOLDER, resource_type: 'image' },
        (error, uploaded) => {
          if (error || !uploaded) {
            reject(error ?? new Error('Cloudinary returned no result'));
            return;
          }
          resolve(uploaded);
        },
      );
      stream.end(file.buffer);
    }).catch((error: unknown) => {
      // Log the real reason, but don't leak Cloudinary internals to the client.
      this.logger.error('Cloudinary upload failed', error);
      throw new InternalServerErrorException('Image upload failed');
    });

    return result.secure_url;
  }
}
