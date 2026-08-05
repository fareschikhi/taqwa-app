import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStudentNoteDto, UpdateStudentNoteDto } from './dto/student-note.dto';

@Injectable()
export class StudentNotesService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
    student: { include: { user: { select: { fullName: true, avatar: true } } } },
    teacher: { include: { user: { select: { fullName: true } } } },
  };

  async create(dto: CreateStudentNoteDto) {
    const note = await this.prisma.studentNote.create({
      data: {
        studentId: dto.studentId,
        teacherId: dto.teacherId,
        note: dto.note,
      },
      include: this.include,
    });
    return note;
  }

  async findByTeacher(teacherId: number) {
    return this.prisma.studentNote.findMany({
      where: { teacherId },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
  }

  async findByStudent(studentId: number) {
    return this.prisma.studentNote.findMany({
      where: { studentId },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
  }

  async update(id: number, dto: UpdateStudentNoteDto) {
    const note = await this.prisma.studentNote.findUnique({ where: { id } });
    if (!note) throw new NotFoundException('الملاحظة غير موجودة');
    return this.prisma.studentNote.update({
      where: { id },
      data: dto,
      include: this.include,
    });
  }

  async remove(id: number) {
    const note = await this.prisma.studentNote.findUnique({ where: { id } });
    if (!note) throw new NotFoundException('الملاحظة غير موجودة');
    return this.prisma.studentNote.delete({ where: { id } });
  }
}
