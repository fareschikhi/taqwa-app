import {
  Injectable,
  NotFoundException,
  ConflictException,
  BadRequestException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CreateStudentDto,
  StudentRegistrationDto,
  UpdateStudentDto,
} from './dto/student.dto';
import { normalizeHadithBooks } from './hadith-books';

@Injectable()
export class StudentsService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
    user: {
      select: {
        id: true,
        fullName: true,
        email: true,
        phone: true,
        avatar: true,
        isActive: true,
        // The admin forms need to tell an adult student from a child one
        // before he is ever assigned to a halaqa, to keep an adults' halaqa
        // picker (and its child counterpart) from ever offering the wrong
        // kind of student in the first place. `role` is the only place that
        // distinction lives before enrolment.
        role: true,
      },
    },
    halaqa: {
      select: {
        id: true,
        name: true,
        level: true,
        teacher: { select: { user: { select: { fullName: true } } } },
      },
    },
    _count: {
      select: { attendance: true, memorization: true, evaluations: true },
    },
  };

  async findAll(params?: {
    teacherId?: number;
    halaqaId?: number;
    search?: string;
    page?: number;
    limit?: number;
    isActive?: boolean;
  }) {
    const page = params?.page ?? 1;
    const limit = params?.limit ?? 50;
    const skip = (page - 1) * limit;

    const whereConditions: any[] = [];

    if (params?.teacherId !== undefined) {
      whereConditions.push({ halaqa: { teacherId: params.teacherId } });
    }
    if (params?.halaqaId !== undefined) {
      whereConditions.push({ halaqaId: params.halaqaId });
    }
    if (params?.isActive !== undefined) {
      whereConditions.push({ user: { isActive: params.isActive } });
    }
    if (params?.search && params.search.trim() !== '') {
      whereConditions.push({
        user: { fullName: { contains: params.search.trim() } },
      });
    }

    const where = whereConditions.length > 0 ? { AND: whereConditions } : {};

    const [data, total] = await Promise.all([
      this.prisma.student.findMany({
        where,
        include: this.include,
        orderBy: { user: { fullName: 'asc' } },
        skip,
        take: limit,
      }),
      this.prisma.student.count({ where }),
    ]);

    return { data, total, page, limit };
  }

  async findOne(id: number) {
    const s = await this.prisma.student.findUnique({
      where: { id },
      include: this.include,
    });
    if (!s) throw new NotFoundException('الطالب غير موجود');
    return s;
  }

  /// Mirrors `HalaqasService.assertEnrolmentMatches` from the other side of
  /// the same relation. That check only runs when a halaqa's own roster is
  /// written, but a student can just as well arrive at a halaqa through this
  /// service's `halaqaId`, so the pairing has to be re-checked here too or an
  /// admin can slip a child into an adults' halaqa (or the reverse) through
  /// this door instead. A missing halaqa is left for the foreign key
  /// constraint downstream to report rather than duplicated here.
  private async assertHalaqaMatches(halaqaId: number, isAdult: boolean) {
    const halaqa = await this.prisma.halaqa.findUnique({
      where: { id: halaqaId },
      select: { isAdult: true },
    });
    if (!halaqa) return;

    if (halaqa.isAdult !== isAdult) {
      throw new BadRequestException(
        halaqa.isAdult
          ? 'حلقة الكبار تقبل الطلاب البالغين فقط'
          : 'لا يمكن إضافة طالب بالغ إلى حلقة عادية',
      );
    }
  }

  /// Copies the registration-form details a request actually carries, so an
  /// edit that leaves them out does not wipe what is stored. '' clears one.
  private registrationFields(dto: StudentRegistrationDto) {
    const data: Record<string, string | boolean | null> = {};
    for (const key of [
      'schoolLevel',
      'healthStatus',
      'familyStatus',
      'fatherJob',
      'motherJob',
      'occupation',
      'externalActivities',
    ] as const) {
      const value = dto[key];
      if (value !== undefined) data[key] = value.trim() === '' ? null : value.trim();
    }
    if (dto.isMarried !== undefined) data.isMarried = dto.isMarried;
    return data;
  }

  /// The stored book list and the flag derived from it, written together so
  /// the two can never disagree.
  private hadithFields(books: string[]) {
    const hadithBooks = normalizeHadithBooks(books);
    return { hadithBooks, tracksHadith: hadithBooks.length > 0 };
  }

  /// Phone and email are both unique on `users`; name the one that clashed.
  private conflict(error: any) {
    const target = String(error?.meta?.target ?? '');
    return new ConflictException(
      target.includes('email')
        ? 'البريد الإلكتروني مستخدم بالفعل'
        : 'رقم الهاتف مستخدم بالفعل',
    );
  }

  async create(dto: CreateStudentDto) {
    const phone =
      dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : undefined;
    const email =
      dto.email && dto.email.trim() !== '' ? dto.email.trim() : undefined;

    if (dto.isAdult && !dto.password) {
      throw new BadRequestException('كلمة المرور مطلوبة للطالب البالغ');
    }

    if (dto.halaqaId !== undefined) {
      await this.assertHalaqaMatches(dto.halaqaId, dto.isAdult ?? false);
    }

    try {
      const user = await this.prisma.user.create({
        data: {
          fullName: dto.fullName,
          phone,
          email,
          // A child student is a record, not an account: the role classifies
          // the row while the null hash keeps the login door shut. An adult
          // student is his own guardian, so his account is real.
          passwordHash: dto.isAdult
            ? await bcrypt.hash(dto.password!, 10)
            : null,
          // The admin typed that password, so it is a temporary one.
          mustChangePassword: dto.isAdult ?? false,
          role: dto.isAdult ? 'ADULT_STUDENT' : 'STUDENT',
          avatar: dto.avatar,
          student: {
            create: {
              birthDate: dto.birthDate ? new Date(dto.birthDate) : undefined,
              address: dto.address?.trim() || undefined,
              // An adult student has no parent by construction.
              parentId: dto.isAdult ? undefined : (dto.parentId ?? undefined),
              halaqaId: dto.halaqaId ?? undefined,
              ...this.hadithFields(dto.hadithBooks ?? []),
              ...this.registrationFields(dto),
            },
          },
        },
        include: { student: true },
      });

      if (user.student) {
        return await this.findOne(user.student.id);
      }
      return user;
    } catch (error: any) {
      if (error?.code === 'P2002') throw this.conflict(error);
      throw error;
    }
  }

  async update(id: number, dto: UpdateStudentDto) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: { user: { select: { role: true } } },
    });
    if (!student) throw new NotFoundException('الطالب غير موجود');

    const userUpdate: any = {};
    if (dto.fullName) userUpdate.fullName = dto.fullName;

    if (dto.phone !== undefined) {
      const phone =
        dto.phone && dto.phone.trim() !== '' ? dto.phone.trim() : null;
      if (phone !== null) {
        const existing = await this.prisma.user.findFirst({
          where: { phone, NOT: { id: student.userId } },
        });
        if (existing) {
          throw new ConflictException('رقم الهاتف مستخدم بالفعل');
        }
      }
      userUpdate.phone = phone;
    }

    if (dto.email !== undefined) {
      userUpdate.email = dto.email.trim() === '' ? null : dto.email.trim();
    }

    if (dto.avatar) userUpdate.avatar = dto.avatar;

    const studentUpdate: any = { ...this.registrationFields(dto) };
    if (dto.birthDate) studentUpdate.birthDate = new Date(dto.birthDate);
    if (dto.address !== undefined) {
      studentUpdate.address = dto.address.trim() === '' ? null : dto.address.trim();
    }
    if (dto.parentId !== undefined) studentUpdate.parentId = dto.parentId;
    if (dto.halaqaId !== undefined) {
      // Clearing the halaqa (null) has nothing to mismatch against, so only a
      // move into an actual halaqa needs the pairing checked.
      if (dto.halaqaId !== null) {
        await this.assertHalaqaMatches(
          dto.halaqaId,
          student.user.role === 'ADULT_STUDENT',
        );
      }
      studentUpdate.halaqaId = dto.halaqaId;
    }
    // Compared against undefined, not truthiness: '' is how a teacher retracts
    // a rating, and a falsy check would silently drop that.
    if (dto.currentRating !== undefined)
      studentUpdate.currentRating = dto.currentRating;
    if (dto.hadithBooks !== undefined)
      Object.assign(studentUpdate, this.hadithFields(dto.hadithBooks));

    try {
      if (Object.keys(userUpdate).length > 0) {
        await this.prisma.user.update({
          where: { id: student.userId },
          data: userUpdate,
        });
      }
      return await this.prisma.student.update({
        where: { id },
        data: studentUpdate,
        include: this.include,
      });
    } catch (error: any) {
      if (error?.code === 'P2002') throw this.conflict(error);
      throw error;
    }
  }

  async getStudentProfile(id: number) {
    const student = await this.prisma.student.findUnique({
      where: { id },
      include: {
        user: {
          // role tells the profile which registration form (child or adult)
          // the student's details were filled from.
          select: {
            fullName: true,
            email: true,
            phone: true,
            avatar: true,
            role: true,
          },
        },
        halaqa: {
          select: {
            name: true,
            level: true,
            teacher: { select: { user: { select: { fullName: true } } } },
            // A parent's point of contact for the halaqa. Only managers who
            // can still sign in and have a phone are worth a Telegram button.
            managers: {
              where: { manager: { user: { isActive: true, phone: { not: null } } } },
              orderBy: { assignedAt: 'asc' },
              select: {
                manager: {
                  select: {
                    id: true,
                    user: { select: { fullName: true, phone: true } },
                  },
                },
              },
            },
          },
        },
        // Who to contact about this student. Optional by design: an adult
        // student is his own guardian and has no parent row at all, so the
        // profile simply carries null and the UI omits the card.
        parent: {
          select: {
            user: { select: { fullName: true, phone: true, avatar: true } },
          },
        },
        memorization: { orderBy: { recordedAt: 'desc' }, take: 10 },
        evaluations: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            teacher: { include: { user: { select: { fullName: true } } } },
          },
        },
        notes: {
          orderBy: { createdAt: 'desc' },
          take: 5,
          include: {
            teacher: { include: { user: { select: { fullName: true } } } },
          },
        },
        _count: { select: { attendance: true } },
      },
    });
    if (!student) throw new NotFoundException('الطالب غير موجود');

    // Arriving late is still arriving, so LATE counts towards the rate
    // alongside PRESENT — only an ABSENT day is held against the student.
    const attendedCount = await this.prisma.attendance.count({
      where: { studentId: id, status: { in: ['PRESENT', 'LATE'] } },
    });
    const totalAttendance = student._count.attendance;
    const attendanceRate =
      totalAttendance > 0
        ? Math.round((attendedCount / totalAttendance) * 100)
        : 0;

    return { ...student, attendanceRate };
  }

  async remove(id: number) {
    const student = await this.prisma.student.findUnique({ where: { id } });
    if (!student) throw new NotFoundException('الطالب غير موجود');
    // Hard delete — removing the user cascades to the student row and all of
    // its attendance, memorization, evaluations, notes and justifications.
    return this.prisma.user.delete({ where: { id: student.userId } });
  }
}
