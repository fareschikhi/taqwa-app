import {
  Body,
  Controller,
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
import { MemorizationService } from './memorization.service';
import {
  CreateMemorizationDto,
  UpdateMemorizationDto,
} from './dto/memorization.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('memorization')
export class MemorizationController {
  constructor(private memorizationService: MemorizationService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateMemorizationDto) {
    return this.memorizationService.create(dto);
  }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) {
    return this.memorizationService.findByStudent(id);
  }

  @Get('student/:id/progress')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.STUDENT)
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
}
