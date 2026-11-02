import { Injectable } from '@nestjs/common';

/** What the notifier needs to know about a message that was just sent. */
export interface SentMessage {
  parentId: number;
  parentUserId: number;
  parentName: string;
  fromStaff: boolean;
  /** Text for the push body: the message, or the photo label. */
  text: string;
}

/** Tells the other side about a new message. Filled in by the push task. */
@Injectable()
export class ChatNotifier {
  async messageSent(_message: SentMessage): Promise<void> {}
}
