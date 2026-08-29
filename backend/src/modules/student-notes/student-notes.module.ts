import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { StudentNotesController } from './student-notes.controller';
import { StudentNotesService } from './student-notes.service';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [PrismaModule, NotificationsModule],
  controllers: [StudentNotesController],
  providers: [StudentNotesService],
})
export class StudentNotesModule {}
