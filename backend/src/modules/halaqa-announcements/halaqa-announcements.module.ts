import { Module } from '@nestjs/common';
import { PrismaModule } from '../../prisma/prisma.module';
import { HalaqaAnnouncementsController } from './halaqa-announcements.controller';
import { HalaqaAnnouncementsService } from './halaqa-announcements.service';

@Module({
  imports: [PrismaModule],
  controllers: [HalaqaAnnouncementsController],
  providers: [HalaqaAnnouncementsService],
})
export class HalaqaAnnouncementsModule {}
