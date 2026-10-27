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

  private readonly student = {
    include: { user: { select: { fullName: true, avatar: true } } },
  };

  private readonly include = {
    recipients: { include: { student: this.student }, orderBy: { studentId: 'asc' as const } },
    teacher: { include: { user: { select: { fullName: true } } } },
  };

  /**
   * Keeps the shape a note had when it named one student: `studentId` and
   * `student` are the first recipient (the only one, for most notes), and
   * `recipients` lists them all. Builds of the app already on phones read the
   * flat fields, so they still show every note.
   */
  private flatten<T extends { recipients: { studentId: number; student: unknown }[] }>(
    note: T,
  ) {
    const first = note.recipients[0];
    return { ...note, studentId: first?.studentId ?? null, student: first?.student ?? null };
  }

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

  private async write(studentIds: number[], teacherId: number, text: string) {
    // One row and its recipients in a single insert, so a note never exists
    // with only some of its students attached.
    const note = await this.prisma.studentNote.create({
      data: {
        teacherId,
        note: text,
        recipients: { create: studentIds.map((studentId) => ({ studentId })) },
      },
      include: this.include,
    });
    await Promise.all(studentIds.map((id) => this.notifyStudent(id, text)));
    return this.flatten(note);
  }

  async create(dto: CreateStudentNoteDto) {
    return this.write([dto.studentId], dto.teacherId, dto.note);
  }

  async createBulk(dto: CreateBulkStudentNoteDto) {
    // A repeated id would address the note twice to one child.
    return this.write([...new Set(dto.studentIds)], dto.teacherId, dto.note);
  }

  async findByTeacher(teacherId: number) {
    const notes = await this.prisma.studentNote.findMany({
      // A note whose students have all been deleted is about no one now.
      where: { teacherId, recipients: { some: {} } },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
    return notes.map((n) => this.flatten(n));
  }

  async findByStudent(studentId: number) {
    const notes = await this.prisma.studentNote.findMany({
      where: { recipients: { some: { studentId } } },
      include: {
        ...this.include,
        // Only this student's own row: a parent reading a note sent to the
        // whole halaqa must not get the names of everyone else's children.
        recipients: { where: { studentId }, include: { student: this.student } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return notes.map((n) => this.flatten(n));
  }

  async update(id: number, dto: UpdateStudentNoteDto) {
    const note = await this.prisma.studentNote.findUnique({ where: { id } });
    if (!note) throw new NotFoundException('الملاحظة غير موجودة');
    const updated = await this.prisma.studentNote.update({
      where: { id },
      data: dto,
      include: this.include,
    });
    return this.flatten(updated);
  }

  async remove(id: number) {
    const note = await this.prisma.studentNote.findUnique({ where: { id } });
    if (!note) throw new NotFoundException('الملاحظة غير موجودة');
    return this.prisma.studentNote.delete({ where: { id } });
  }
}
