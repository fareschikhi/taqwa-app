import { Module } from '@nestjs/common';
import { HalaqasController } from './halaqas.controller';
import { HalaqasService } from './halaqas.service';

@Module({
  controllers: [HalaqasController],
  providers: [HalaqasService],
  exports: [HalaqasService],
})
export class HalaqasModule {}
