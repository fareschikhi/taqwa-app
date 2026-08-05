import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { HalaqasService } from './halaqas.service';
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

  @Get()
  @Roles(Role.ADMIN, Role.TEACHER)
  findAll() {
    return this.halaqasService.findAll();
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.STUDENT)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.halaqasService.findOne(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateHalaqaDto) {
    return this.halaqasService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.halaqasService.remove(id);
  }
}
