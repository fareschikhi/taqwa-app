import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { EvaluationsService } from './evaluations.service';
import { CreateEvaluationDto, UpdateEvaluationDto } from './dto/evaluation.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('evaluations')
export class EvaluationsController {
  constructor(private evaluationsService: EvaluationsService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateEvaluationDto) {
    return this.evaluationsService.create(dto);
  }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) {
    return this.evaluationsService.findByStudent(id);
  }

  // Staff only, deliberately. This `:id` is an evaluation id, not a student
  // id, so StudentOwnershipGuard cannot vouch for it — it reads `params.id` as
  // a student. A parent listed here could therefore read any evaluation in the
  // school by guessing its id. They reach their own child's through
  // `student/:id` above, which the guard does cover.
  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.evaluationsService.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateEvaluationDto) {
    return this.evaluationsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.evaluationsService.remove(id);
  }
}
