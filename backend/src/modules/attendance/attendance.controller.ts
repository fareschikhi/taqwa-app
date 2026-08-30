import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { AttendanceService } from './attendance.service';
import { CreateAttendanceDto, CreateBatchAttendanceDto, UpdateAttendanceDto } from './dto/attendance.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('attendance')
export class AttendanceController {
  constructor(private attendanceService: AttendanceService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateAttendanceDto, @CurrentUser() user: any) {
    return this.attendanceService.create(dto, user ?? null);
  }

  @Post('batch')
  @Roles(Role.ADMIN, Role.TEACHER)
  createBatch(@Body() dto: CreateBatchAttendanceDto, @CurrentUser() user: any) {
    return this.attendanceService.createBatch(dto, user ?? null);
  }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) { return this.attendanceService.findByStudent(id); }

  @Get('student/:id/summary')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  getSummary(@Param('id', ParseIntPipe) id: number) { return this.attendanceService.getStudentAttendanceSummary(id); }

  @Get('week')
  @Roles(Role.ADMIN, Role.MANAGER)
  getWeek() { return this.attendanceService.getWeeklyAttendanceRates(); }

  @Get('date')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  findByDate(@Query('date') date: string) { return this.attendanceService.findByDate(date); }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAttendanceDto,
    @CurrentUser() user: any,
  ) {
    return this.attendanceService.update(id, dto, user ?? null);
  }
}
