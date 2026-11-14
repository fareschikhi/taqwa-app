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

/// Which programs a student follows — the hadith books, and برنامج التسميع —
/// is the admin's call alone. A manager (and, on PATCH, a teacher) reaches
/// the same routes for everything else on the student, so these are refused
/// by role here rather than trusted to the app hiding its controls. Any
/// presence counts, an empty list or `false` included — turning a program
/// off is as much a decision as turning it on.
function assertMaySetPrograms(
  dto: { hadithBooks?: string[]; tracksTasmee?: boolean },
  user: { role?: string },
) {
  const touches =
    dto.hadithBooks !== undefined || dto.tracksTasmee !== undefined;
  if (touches && user?.role !== Role.ADMIN) {
    throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
  }
}

/// Resetting an adult student's password belongs to whoever manages
/// accounts — the admin, or a manager holding MANAGE_ACCOUNTS. A teacher
/// reaches PATCH for the rating, not for logins.
function assertMaySetPassword(
  dto: { password?: string },
  user: { role?: string },
) {
  if (dto.password !== undefined && user?.role === Role.TEACHER) {
    throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
  }
}

/// The overall rating is the teacher's (and the admin's) judgement. A manager
/// holding MANAGE_ACCOUNTS reaches PATCH to edit the student's account, and
/// may read the rating, but not word it.
function assertMaySetRating(
  dto: { currentRating?: string },
  user: { role?: string },
) {
  if (dto.currentRating !== undefined && user?.role === Role.MANAGER) {
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
    @Query('halaqaId') halaqaId?: string,
    @Query('groupByHalaqa') groupByHalaqa?: string,
    // The viewer's own section order, "9,5,3": comes from their phone, so
    // anything that isn't a positive id is dropped rather than rejected.
    @Query('halaqaOrder') halaqaOrder?: string,
  ) {
    return this.studentsService.findAll({
      halaqaOrder: (halaqaOrder ?? '')
        .split(',')
        .map((id) => Number(id))
        .filter((id) => Number.isInteger(id) && id > 0)
        .slice(0, 500),
      teacherId: teacherId ? parseInt(teacherId, 10) : undefined,
      search,
      page: page ? parseInt(page, 10) : undefined,
      limit: limit ? parseInt(limit, 10) : undefined,
      isActive: isActive !== undefined ? isActive === 'true' : undefined,
      halaqaId: halaqaId ? parseInt(halaqaId, 10) : undefined,
      groupByHalaqa: groupByHalaqa === 'true',
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
    assertMaySetPrograms(dto, user);
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
    assertMaySetPrograms(dto, user);
    assertMaySetPassword(dto, user);
    assertMaySetRating(dto, user);
    return this.studentsService.update(id, dto);
  }

  /// The admin's record resets. ADMIN only — no manager permission unlocks
  /// them — because they erase history other staff wrote. The app holds each
  /// clear behind an undo window and only calls DELETE once it has passed,
  /// so these routes are final.
  @Get(':id/records')
  @Roles(Role.ADMIN)
  getRecordsSummary(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.getRecordsSummary(id);
  }

  @Delete(':id/attendance')
  @Roles(Role.ADMIN)
  clearAttendance(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.clearAttendance(id);
  }

  @Delete(':id/memorization')
  @Roles(Role.ADMIN)
  clearMemorization(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.clearMemorization(id);
  }

  @Delete(':id/points')
  @Roles(Role.ADMIN)
  clearPoints(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.clearPoints(id);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.DELETE_ACCOUNTS)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.studentsService.remove(id);
  }
}
