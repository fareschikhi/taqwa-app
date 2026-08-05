import { Body, Controller, Delete, ForbiddenException, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { ParentsService } from './parents.service';
import { CreateParentDto, UpdateParentDto } from './dto/parent.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('parents')
export class ParentsController {
  constructor(private parentsService: ParentsService) {}

  @Post()
  @Roles(Role.ADMIN)
  create(@Body() dto: CreateParentDto) {
    return this.parentsService.create(dto);
  }

  @Get()
  @Roles(Role.ADMIN, Role.TEACHER)
  findAll() {
    return this.parentsService.findAll();
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT)
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
  @Roles(Role.ADMIN, Role.PARENT)
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
  @Roles(Role.ADMIN)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.parentsService.remove(id);
  }
}
