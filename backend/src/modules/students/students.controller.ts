import {
  Body,
  Controller,
  Delete,
  ForbiddenException,
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
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import {
  ManagerPermission,
  RequirePermission,
} from '../../common/decorators/permissions.decorator';
import { StudentsService } from './students.service';
import { CreateStudentDto, UpdateStudentDto } from './dto/student.dto';

/// Hadith tracking is the admin's call alone. A manager (and, on PATCH, a
/// teacher) reaches the same routes for everything else on the student, so
/// the flag is refused by role here rather than trusted to the app hiding
/// its switch. Any presence counts, `false` included — clearing the flag is
/// as much a decision as setting it.
function assertMaySetTracksHadith(
  dto: { tracksHadith?: boolean },
  user: { role?: string },
) {
  if (dto.tracksHadith !== undefined && user?.role !== Role.ADMIN) {
    throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
  }
}

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
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findOne(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.findOne(id);
  }

  @Get(':id/profile')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.MANAGER, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  getProfile(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.getStudentProfile(id);
  }

  @Post()
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  create(@Body() dto: CreateStudentDto, @CurrentUser() user: any) {
    assertMaySetTracksHadith(dto, user);
    return this.studentsService.create(dto);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.MANAGER)
  @RequirePermission(ManagerPermission.MANAGE_ACCOUNTS)
  update(
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateStudentDto,
    @CurrentUser() user: any,
  ) {
    assertMaySetTracksHadith(dto, user);
    return this.studentsService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.DELETE_ACCOUNTS)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.remove(id);
  }
}
