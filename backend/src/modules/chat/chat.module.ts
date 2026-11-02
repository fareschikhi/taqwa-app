import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { ChatController } from './chat.controller';
import { ChatNotifier } from './chat-notifier';
import { ChatPhotos } from './chat-photos';
import { ChatService } from './chat.service';

@Module({
  imports: [PrismaModule],
  controllers: [ChatController],
  providers: [ChatService, ChatNotifier, ChatPhotos],
})
export class ChatModule {}
