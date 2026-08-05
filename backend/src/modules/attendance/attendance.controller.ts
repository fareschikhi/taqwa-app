import { Body, Controller, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { AttendanceService } from './attendance.service';
import { CreateAttendanceDto, CreateBatchAttendanceDto, UpdateAttendanceDto } from './dto/attendance.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('attendance')
export class AttendanceController {
  constructor(private attendanceService: AttendanceService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateAttendanceDto) { return this.attendanceService.create(dto); }

  @Post('batch')
  @Roles(Role.ADMIN, Role.TEACHER)
  createBatch(@Body() dto: CreateBatchAttendanceDto) { return this.attendanceService.createBatch(dto); }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.STUDENT, Role.MANAGER)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) { return this.attendanceService.findByStudent(id); }

  @Get('student/:id/summary')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.STUDENT, Role.MANAGER)
  @UseGuards(StudentOwnershipGuard)
  getSummary(@Param('id', ParseIntPipe) id: number) { return this.attendanceService.getStudentAttendanceSummary(id); }

  @Get('date')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  findByDate(@Query('date') date: string) { return this.attendanceService.findByDate(date); }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateAttendanceDto) {
    return this.attendanceService.update(id, dto);
  }
}
