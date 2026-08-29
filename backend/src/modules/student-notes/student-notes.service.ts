import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateStudentNoteDto, UpdateStudentNoteDto } from './dto/student-note.dto';
import { NotificationsService } from '../notifications/notifications.service';
import { notePreview } from './note-preview';

@Injectable()
export class StudentNotesService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  private readonly include = {
    student: { include: { user: { select: { fullName: true, avatar: true } } } },
    teacher: { include: { user: { select: { fullName: true } } } },
  };

  /**
   * Tells the student's parent that a note was written. Writing the note is
   * the whole event, so unlike attendance there is no prior state to compare
   * against — every created note announces itself once.
   *
   * The body carries a preview rather than the note in full: the parent reads
   * the whole thing on their dashboard, and a body short enough for a list row
   * is also short enough for the lock screen once this delivers over push.
   */
  private async notifyParent(studentId: number, note: string) {
    // Runs after the note is written, and its failures are swallowed: a
    // notification that does not send must not cost the note that prompted it.
    try {
      const student = await this.prisma.student.findUnique({
        where: { id: studentId },
        select: {
          parentId: true,
          user: { select: { fullName: true } },
          parent: { select: { userId: true } },
        },
      });
      const parentUserId = student?.parent?.userId;
      if (!parentUserId) return;

      // A parent may have several children, and a note's text will not
      // reliably name the one it is about.
      const name = student?.user?.fullName ?? '';
      await this.notifications.create({
        userId: parentUserId,
        title: 'ملاحظة من المعلم',
        body: `${name}: ${notePreview(note)}`,
      });
    } catch (_) {
      // Deliberately silent — see above.
    }
  }

  async create(dto: CreateStudentNoteDto) {
    const note = await this.prisma.studentNote.create({
      data: {
        studentId: dto.studentId,
        teacherId: dto.teacherId,
        note: dto.note,
      },
      include: this.include,
    });
    await this.notifyParent(dto.studentId, dto.note);
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
