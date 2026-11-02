import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { PushModule } from '../push/push.module';
import { ChatController } from './chat.controller';
import { ChatNotifier } from './chat-notifier';
import { ChatPhotos } from './chat-photos';
import { ChatService } from './chat.service';

@Module({
  imports: [PrismaModule, PushModule],
  controllers: [ChatController],
  providers: [ChatService, ChatNotifier, ChatPhotos],
})
export class ChatModule {}
