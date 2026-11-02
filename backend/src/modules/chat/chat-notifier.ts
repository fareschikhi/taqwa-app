import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { PushService } from '../push/push.service';
import { staffUserIdsForParent } from './chat-access';
import { STAFF_LABEL } from './chat-serializer';

/** What the notifier needs to know about a message that was just sent. */
export interface SentMessage {
  parentId: number;
  parentUserId: number;
  parentName: string;
  fromStaff: boolean;
  /** Text for the push body: the message, or the photo label. */
  text: string;
}

/**
 * Tells the other side a message arrived.
 *
 * A staff reply goes to the parent only, signed "الإدارة"; other staff are
 * not pushed (they see it in the shared thread). A parent's message goes to
 * every staff member who may see that thread right now. Edits and deletes
 * push nothing: an open chat picks them up on its next poll.
 *
 * Best effort, like all push here: the message is already stored, so a
 * failure is logged and never reaches the sender.
 */
@Injectable()
export class ChatNotifier {
  private readonly logger = new Logger(ChatNotifier.name);

  constructor(
    private prisma: PrismaService,
    private push: PushService,
  ) {}

  async messageSent(message: SentMessage): Promise<void> {
    const data = { route: 'chat', parentId: String(message.parentId) };
    try {
      if (message.fromStaff) {
        await this.push.sendToUser(
          message.parentUserId,
          STAFF_LABEL,
          message.text,
          data,
        );
        return;
      }
      const staff = await staffUserIdsForParent(this.prisma, message.parentId);
      await this.push.sendToUsers(
        staff,
        message.parentName,
        message.text,
        data,
      );
    } catch (e) {
      this.logger.warn(`Chat push failed: ${(e as Error).message}`);
    }
  }
}
