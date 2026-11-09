import { Module } from '@nestjs/common';
import { StudentOfMonthController } from './student-of-month.controller';
import { StudentOfMonthService } from './student-of-month.service';

@Module({
  controllers: [StudentOfMonthController],
  providers: [StudentOfMonthService],
})
export class StudentOfMonthModule {}
