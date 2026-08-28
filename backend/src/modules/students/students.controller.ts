import {
  Body,
  Controller,
  Delete,
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
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  ManagerPermission,
  RequirePermission,
} from '../../common/decorators/permissions.decorator';
import { StudentsService } from './students.service';
import { CreateStudentDto, UpdateStudentDto } from './dto/student.dto';

@UseGuards(JwtAuthGuard, RolesGuard, ManagerPermissionGuard)
@Controller('students')
export class StudentsController {
  constructor(private studentsService: StudentsService) {}

  @Get()
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  findAll(
    @Query('teacherId') teacherId?: string,
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
    @Query('isActive') isActive?: string,
  ) {
    return this.studentsService.findAll({
      teacherId: teacherId ? parseInt(teacherId, 10) : undefined,
      search,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
      isActive: isActive !== undefined ? isActive === 'true' : undefined,
    });
  }

  @Get(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER)
  @UseGuards(StudentOwnershipGuard)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.findOne(id);
  }

  @Get(':id/profile')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER)
  @UseGuards(StudentOwnershipGuard)
  getProfile(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.getStudentProfile(id);
  }

  @Post()
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  create(@Body() dto: CreateStudentDto) {
    return this.studentsService.create(dto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateStudentDto) {
    return this.studentsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.DELETE_ACCOUNTS)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.remove(id);
  }
}
