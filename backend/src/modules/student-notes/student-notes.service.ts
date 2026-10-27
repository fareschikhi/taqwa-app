import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateBulkStudentNoteDto,
  CreateStudentNoteDto,
  UpdateStudentNoteDto,
} from './dto/student-note.dto';
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
   * Tells whoever answers for the student that a note was written: the parent
   * for a child, and the adult student himself, who has no parent row by
   * construction. Writing the note is the whole event, so unlike attendance
   * there is no prior state to compare against — every created note announces
   * itself once.
   *
   * The body carries a preview rather than the note in full: the reader sees
   * the whole thing on their dashboard, and a body short enough for a list row
   * is also short enough for the lock screen once this delivers over push.
   */
  private async notifyStudent(studentId: number, note: string) {
    // Runs after the note is written, and its failures are swallowed: a
    // notification that does not send must not cost the note that prompted it.
    try {
      const student = await this.prisma.student.findUnique({
        where: { id: studentId },
        select: {
          userId: true,
          user: { select: { fullName: true, role: true } },
          parent: { select: { userId: true } },
        },
      });
      const isSelf = student?.user.role === 'ADULT_STUDENT';
      const recipientId =
        student?.parent?.userId ?? (isSelf ? student.userId : null);
      if (!recipientId) return;

      // A parent may have several children, and a note's text will not
      // reliably name the one it is about. An adult reads a note about
      // himself, so his own name would only crowd the preview.
      const name = student?.user?.fullName ?? '';
      await this.notifications.create({
        userId: recipientId,
        studentId,
        title: 'ملاحظة من المعلم',
        body: isSelf ? notePreview(note) : `${name}: ${notePreview(note)}`,
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
    await this.notifyStudent(dto.studentId, dto.note);
    return note;
  }

  async createBulk(dto: CreateBulkStudentNoteDto) {
    // A repeated id would write the same note twice to one child.
    const studentIds = [...new Set(dto.studentIds)];
    // All or nothing: a teacher who sent a note to the class should not have
    // to work out which half of it landed.
    const notes = await this.prisma.$transaction(
      studentIds.map((studentId) =>
        this.prisma.studentNote.create({
          data: { studentId, teacherId: dto.teacherId, note: dto.note },
          include: this.include,
        }),
      ),
    );
    await Promise.all(studentIds.map((id) => this.notifyStudent(id, dto.note)));
    return notes;
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
