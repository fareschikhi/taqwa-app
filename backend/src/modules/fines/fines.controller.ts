import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { FinesService } from './fines.service';
import type { FineActor } from './fines.service';
import { CreateFineDto } from './dto/fine.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('fines')
export class FinesController {
  constructor(private finesService: FinesService) {}

  // The ownership guard is what lets an adult student appear in this list: it
  // holds him to his own :id while leaving staff their cross-student access.
  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) {
    return this.finesService.findByStudent(id);
  }

  @Get('halaqa/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  findByHalaqa(@Param('id', ParseIntPipe) id: number) {
    return this.finesService.findByHalaqa(id);
  }

  // The service, not a guard, holds a teacher to her own halaqa here: the
  // check needs the student the entry is about, which only the body and the
  // stored row can supply.
  @Post()
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  create(@Body() dto: CreateFineDto, @CurrentUser() user: FineActor) {
    return this.finesService.create(dto, user);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  remove(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: FineActor) {
    return this.finesService.remove(id, user);
  }
}
