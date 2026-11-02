import { Injectable } from '@nestjs/common';

/** Private storage for chat photos. Filled in by the photos task. */
@Injectable()
export class ChatPhotos {
  async deleteChatPhoto(_path: string): Promise<void> {}
}
