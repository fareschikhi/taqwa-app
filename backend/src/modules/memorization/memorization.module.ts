import { Module } from '@nestjs/common';
import { MemorizationController } from './memorization.controller';
import { MemorizationService } from './memorization.service';

@Module({
  controllers: [MemorizationController],
  providers: [MemorizationService],
  exports: [MemorizationService],
})
export class MemorizationModule {}
