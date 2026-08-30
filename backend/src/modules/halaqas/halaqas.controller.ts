import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { HalaqasService } from './halaqas.service';
import type { HalaqaActor } from './halaqas.service';
import { CreateHalaqaDto, UpdateHalaqaDto } from './dto/halaqa.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('halaqas')
export class HalaqasController {
  constructor(private halaqasService: HalaqasService) {}

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateHalaqaDto) {
    return this.halaqasService.create(dto);
  }

  // A teacher reads this to find which halaqa a student sits in, so she keeps
  // the route — but the service narrows the rows to her own. The list now
  // carries each halaqa's fine rates, which are not hers to see.
  @Get()
  @Roles(Role.ADMIN, Role.TEACHER)
  findAll(@CurrentUser() user: HalaqaActor) {
    return this.halaqasService.findAll(user ?? null);
  }

  // Staff only. This returns the halaqa's whole roster including every
  // student's phone number, so a parent holding it could walk the ids and
  // collect the contact details of every child in the school.
  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.halaqasService.findOne(id);
  }

  // Admin only. `studentIds` replaces the roster outright and the body carries
  // the fine rates, so a teacher holding this could empty a colleague's halaqa
  // or reprice it. No screen in the app asks a teacher to edit a halaqa.
  @Patch(':id')
  @Roles(Role.ADMIN)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateHalaqaDto) {
    return this.halaqasService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.halaqasService.remove(id);
  }
}
