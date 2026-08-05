import { Body, Controller, Delete, ForbiddenException, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  ManagerPermission,
  RequirePermission,
} from '../../common/decorators/permissions.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ParentsService } from './parents.service';
import { CreateParentDto, UpdateParentDto } from './dto/parent.dto';

@UseGuards(JwtAuthGuard, RolesGuard, ManagerPermissionGuard)
@Controller('parents')
export class ParentsController {
  constructor(private parentsService: ParentsService) {}

  @Post()
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  create(@Body() dto: CreateParentDto) {
    return this.parentsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  findAll() {
    return this.parentsService.findAll();
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  findOne(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    if (user.role === 'PARENT' && user.parent?.id !== id) {
      throw new ForbiddenException('غير مصرح لك بالوصول إلى بيانات هذا الحساب');
    }
    return this.parentsService.findOne(id);
  }

  @Get(':id/children')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER)
  getChildren(@Param('id', ParseIntPipe) id: number, @CurrentUser() user: any) {
    if (user.role === 'PARENT' && user.parent?.id !== id) {
      throw new ForbiddenException('غير مصرح لك بالوصول إلى بيانات هذا الحساب');
    }
    return this.parentsService.findChildren(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.PARENT, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateParentDto,
    @CurrentUser() user: any,
  ) {
    if (user.role === 'PARENT' && user.parent?.id !== id) {
      throw new ForbiddenException('غير مصرح لك بالوصول إلى بيانات هذا الحساب');
    }
    return this.parentsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.DELETE_ACCOUNTS)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.parentsService.remove(id);
  }
}
