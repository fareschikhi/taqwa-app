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
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { CreatePointsDto } from './dto/points.dto';
import type { PointsActor } from './points-access';
import { PointsService } from './points.service';

// Roles here only say who may knock. Which student or account a caller may
// actually reach is decided in the service (points-access.ts), because it
// depends on the halaqa, the parent link or the creator of an entry.
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('points')
export class PointsController {
  constructor(private points: PointsService) {}

  // Declared before the `:id` routes so "me" is never parsed as an id.
  @Get('me')
  @Roles(Role.TEACHER, Role.MANAGER, Role.ADULT_STUDENT)
  mine(@CurrentUser() user: PointsActor) {
    return this.points.summaryForUser(user.id);
  }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER, Role.PARENT, Role.ADULT_STUDENT)
  byStudent(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: PointsActor,
  ) {
    return this.points.summaryForStudent(id, user);
  }

  // Teachers' and managers' points are the admin's alone to see.
  @Get('user/:id')
  @Roles(Role.ADMIN)
  byUser(@Param('id', ParseIntPipe) id: number) {
    return this.points.summaryForUser(id);
  }

  @Get('halaqa/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  byHalaqa(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: PointsActor,
  ) {
    return this.points.halaqaTotals(id, user);
  }

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  create(@Body() dto: CreatePointsDto, @CurrentUser() user: PointsActor) {
    return this.points.create(dto, user);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() user: PointsActor,
  ) {
    return this.points.remove(id, user);
  }
}
