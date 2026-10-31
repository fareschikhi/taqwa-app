import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { TeachersService } from './teachers.service';
import { CreateTeacherDto, UpdateTeacherDto } from './dto/teacher.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('teachers')
export class TeachersController {
  constructor(private teachersService: TeachersService) {}

  @Get()
  @Roles(Role.ADMIN, Role.TEACHER)
  findAll() { return this.teachersService.findAll(); }

  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  findOne(@Param('id', ParseIntPipe) id: number) { return this.teachersService.findOne(id); }

  // `halaqaId` narrows the three dashboard aggregates to one of the teacher's
  // halaqas; without it they cover all of them.
  @Get(':id/attendance-summary')
  @Roles(Role.ADMIN, Role.TEACHER)
  getAttendanceSummary(
    @Param('id', ParseIntPipe) id: number,
    @Query('halaqaId', new ParseIntPipe({ optional: true })) halaqaId?: number,
  ) {
    return this.teachersService.getTeacherAttendanceSummary(id, halaqaId);
  }

  @Get(':id/revision-needed')
  @Roles(Role.ADMIN, Role.TEACHER)
  getRevisionNeeded(
    @Param('id', ParseIntPipe) id: number,
    @Query('halaqaId', new ParseIntPipe({ optional: true })) halaqaId?: number,
  ) {
    return this.teachersService.getRevisionNeeded(id, halaqaId);
  }

  @Get(':id/memorization-progress')
  @Roles(Role.ADMIN, Role.TEACHER)
  getMemorizationProgress(
    @Param('id', ParseIntPipe) id: number,
    @Query('halaqaId', new ParseIntPipe({ optional: true })) halaqaId?: number,
  ) {
    return this.teachersService.getMemorizationProgress(id, halaqaId);
  }

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateTeacherDto) { return this.teachersService.create(dto); }

  @Patch(':id')
  @Roles(Role.ADMIN)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateTeacherDto) {
    return this.teachersService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) { return this.teachersService.remove(id); }
}
