import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { ManagersService } from './managers.service';
import {
  CreateManagerDto,
  UpdateManagerDto,
  UpdateManagerStatusDto,
} from './dto/manager.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('managers')
export class ManagersController {
  constructor(private managersService: ManagersService) {}

  @Get()
  @Roles(Role.ADMIN)
  findAll() {
    return this.managersService.findAll();
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.managersService.findOne(id);
  }

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateManagerDto) {
    return this.managersService.create(dto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateManagerDto,
  ) {
    return this.managersService.update(id, dto);
  }

  @Patch(':id/status')
  @Roles(Role.ADMIN)
  updateStatus(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateManagerStatusDto,
  ) {
    return this.managersService.updateStatus(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.managersService.remove(id);
  }

  @Get(':id/students')
  @Roles(Role.ADMIN, Role.MANAGER)
  getStudents(@Param('id', ParseIntPipe) id: number) {
    return this.managersService.getStudents(id);
  }

  @Get(':id/halaqas')
  @Roles(Role.ADMIN, Role.MANAGER)
  getHalaqas(@Param('id', ParseIntPipe) id: number) {
    return this.managersService.getHalaqas(id);
  }
}
