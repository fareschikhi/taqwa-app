import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { IsInt } from 'class-validator';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { PointsActor } from '../points/points-access';
import { StudentOfMonthService } from './student-of-month.service';

export class SelectStudentOfMonthDto {
  @IsInt() halaqaId: number;
  @IsInt() studentId: number;
}

// Which halaqa a caller reaches is decided in the service, like points.
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('student-of-month')
export class StudentOfMonthController {
  constructor(private service: StudentOfMonthService) {}

  @Get('mine')
  @Roles(
    Role.ADMIN,
    Role.TEACHER,
    Role.MANAGER,
    Role.PARENT,
    Role.STUDENT,
    Role.ADULT_STUDENT,
  )
  mine(@CurrentUser() user: PointsActor) {
    return this.service.shown(user);
  }

  @Get('pending')
  @Roles(Role.TEACHER)
  pending(@CurrentUser() user: PointsActor) {
    return this.service.pending(user);
  }

  @Post()
  @Roles(Role.TEACHER)
  select(
    @Body() dto: SelectStudentOfMonthDto,
    @CurrentUser() user: PointsActor,
  ) {
    return this.service.select(user, dto);
  }
}
