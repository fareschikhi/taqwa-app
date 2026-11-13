import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { MemorizationService } from './memorization.service';
import {
  CreateGroupMemorizationDto,
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('memorization')
export class MemorizationController {
  constructor(private memorizationService: MemorizationService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateMemorizationDto, @CurrentUser() user: any) {
    return this.memorizationService.create(dto, user ?? null);
  }

  /// One recitation for a whole group of students. Teachers only reach their
  /// own halaqa's students; the service enforces it.
  @Post('group')
  @Roles(Role.ADMIN, Role.TEACHER)
  createGroup(
    @Body() dto: CreateGroupMemorizationDto,
    @CurrentUser() user: any,
  ) {
    return this.memorizationService.createGroup(dto, user ?? null);
  }

  @Get('student/:id')
  @Roles(
    Role.ADMIN,
    Role.TEACHER,
    Role.PARENT,
    Role.MANAGER,
    Role.ADULT_STUDENT,
  )
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) {
    return this.memorizationService.findByStudent(id);
  }

  @Get('student/:id/progress')
  @Roles(
    Role.ADMIN,
    Role.TEACHER,
    Role.PARENT,
    Role.MANAGER,
    Role.ADULT_STUDENT,
  )
  @UseGuards(StudentOwnershipGuard)
  getProgress(@Param('id', ParseIntPipe) id: number) {
    return this.memorizationService.getStudentProgress(id);
  }

  @Get('date')
  @Roles(Role.ADMIN, Role.TEACHER)
  findByDate(@Query('date') date: string) {
    return this.memorizationService.findByDate(date);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateMemorizationDto,
  ) {
    return this.memorizationService.update(id, dto);
  }

  /// A recitation recorded by mistake. Teachers only reach their own
  /// halaqa's students; the service enforces it.
  @Delete(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    return this.memorizationService.remove(id, user ?? null);
  }
}
