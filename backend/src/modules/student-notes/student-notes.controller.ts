import { Body, Controller, Delete, Get, Param, ParseIntPipe, Patch, Post, UseGuards } from '@nestjs/common';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { StudentOwnershipGuard } from '../../common/guards/student-ownership.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { StudentNotesService } from './student-notes.service';
import {
  CreateBulkStudentNoteDto,
  CreateStudentNoteDto,
  UpdateStudentNoteDto,
} from './dto/student-note.dto';

@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('student-notes')
export class StudentNotesController {
  constructor(private studentNotesService: StudentNotesService) {}

  @Post()
  @Roles(Role.ADMIN, Role.TEACHER)
  create(@Body() dto: CreateStudentNoteDto) {
    return this.studentNotesService.create(dto);
  }

  @Post('bulk')
  @Roles(Role.ADMIN, Role.TEACHER)
  createBulk(@Body() dto: CreateBulkStudentNoteDto) {
    return this.studentNotesService.createBulk(dto);
  }

  @Get('teacher/:id')
  @Roles(Role.ADMIN, Role.TEACHER)
  findByTeacher(@Param('id', ParseIntPipe) id: number) {
    return this.studentNotesService.findByTeacher(id);
  }

  @Get('student/:id')
  @Roles(Role.ADMIN, Role.TEACHER, Role.PARENT, Role.ADULT_STUDENT)
  @UseGuards(StudentOwnershipGuard)
  findByStudent(@Param('id', ParseIntPipe) id: number) {
    return this.studentNotesService.findByStudent(id);
  }

  @Patch(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  update(@Param('id', ParseIntPipe) id: number, @Body() dto: UpdateStudentNoteDto) {
    return this.studentNotesService.update(id, dto);
  }

  @Delete(':id')
  @Roles(Role.ADMIN, Role.TEACHER)
  remove(@Param('id', ParseIntPipe) id: number) {
    return this.studentNotesService.remove(id);
  }
}
