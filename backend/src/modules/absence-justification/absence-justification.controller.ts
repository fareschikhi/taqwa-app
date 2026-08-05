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
import { Roles } from '../../common/decorators/roles.decorator';
import { AbsenceJustificationService } from './absence-justification.service';
import {
  CreateAbsenceJustificationDto,
  UpdateAbsenceJustificationDto,
} from './dto/absence-justification.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('absence-justifications')
export class AbsenceJustificationController {
  constructor(
    private absenceJustificationService: AbsenceJustificationService,
  ) {}

  @Get()
  @Roles(Role.ADMIN, Role.MANAGER)
  findAll(
    @Query('managerId') managerId?: string,
    @Query('studentId') studentId?: string,
  ) {
    return this.absenceJustificationService.findAll(
      managerId ? parseInt(managerId) : undefined,
      studentId ? parseInt(studentId) : undefined,
    );
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.absenceJustificationService.findOne(id);
  }

  @Post()
  @Roles(Role.ADMIN, Role.MANAGER)
  create(@Body() dto: CreateAbsenceJustificationDto) {
    return this.absenceJustificationService.create(dto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateAbsenceJustificationDto,
  ) {
    return this.absenceJustificationService.update(id, dto);
  }
}
