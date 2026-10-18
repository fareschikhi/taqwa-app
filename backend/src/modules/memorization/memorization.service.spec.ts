import { BadRequestException } from '@nestjs/common';
import {
  AttendanceStatus,
  Memorization,
  MemorizationSubject,
} from '@prisma/client';
import { MEMORIZATION_ERROR, MemorizationService } from './memorization.service';
import { HADITH_BOOKS } from '../students/hadith-books';

describe('MemorizationService.create attendance gate', () => {
  const makePrisma = (status: AttendanceStatus | null) => ({
    attendance: {
      findUnique: jest
        .fn()
        .mockResolvedValue(status === null ? null : { id: 1, status }),
    },
    memorizationProgress: {
      create: jest.fn().mockResolvedValue({ id: 10 }),
    },
  });

  const dto = {
    studentId: 7,
    surahNumber: 2,
    amountDone: 1,
    memorizationType: Memorization.MEMORIZING,
  };

  it('refuses to record memorization for a student marked absent today', async () => {
    const prisma = makePrisma(AttendanceStatus.ABSENT);
    const service = new MemorizationService(prisma as any);

    await expect(service.create(dto)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.memorizationProgress.create).not.toHaveBeenCalled();
  });

  // The app shows a dedicated "student is absent" message for this case. It has
  // only the response body to go on, since an over-large amount is a 400 too,
  // so the code has to be what distinguishes them.
  it('tags the absence rejection with STUDENT_ABSENT', async () => {
    const prisma = makePrisma(AttendanceStatus.ABSENT);
    const service = new MemorizationService(prisma as any);

    await expect(service.create(dto)).rejects.toMatchObject({
      response: { code: MEMORIZATION_ERROR.STUDENT_ABSENT },
    });
  });

  it('leaves an over-large amount untagged, so it is not reported as absence', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    const service = new MemorizationService(prisma as any);

    // Revision is counted in hizbs, of which there are only 60.
    const tooMany = {
      ...dto,
      memorizationType: Memorization.SMALLREVISION,
      amountDone: 61,
    };

    await expect(service.create(tooMany)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.create(tooMany)).rejects.not.toMatchObject({
      response: { code: MEMORIZATION_ERROR.STUDENT_ABSENT },
    });
  });

  it('records memorization for a present student', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('records memorization for a late student', async () => {
    const prisma = makePrisma(AttendanceStatus.LATE);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('records memorization when attendance has not been taken yet', async () => {
    const prisma = makePrisma(null);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });
});

describe('MemorizationService hadith subject', () => {
  const makePrisma = (
    opts: {
      attendanceStatus?: AttendanceStatus | null;
      tracksHadith?: boolean;
      hadithBooks?: string[];
    } = {},
  ) => ({
    attendance: {
      findUnique: jest
        .fn()
        .mockResolvedValue(
          opts.attendanceStatus == null
            ? null
            : { id: 1, status: opts.attendanceStatus },
        ),
    },
    student: {
      findUnique: jest.fn().mockResolvedValue({
        tracksHadith: opts.tracksHadith ?? true,
        hadithBooks: opts.hadithBooks ?? [HADITH_BOOKS[0]],
      }),
    },
    memorizationProgress: {
      create: jest.fn().mockResolvedValue({ id: 20 }),
      findUnique: jest.fn().mockResolvedValue({
        id: 20,
        studentId: 7,
        subject: MemorizationSubject.HADITH,
        surahNumber: null,
        hadithReference: 'حديث النية',
        memorizationType: Memorization.MEMORIZING,
        amountDone: 1,
      }),
      update: jest.fn().mockResolvedValue({ id: 20 }),
    },
  });

  const hadithDto = {
    studentId: 7,
    amountDone: 1,
    memorizationType: Memorization.MEMORIZING,
    subject: MemorizationSubject.HADITH,
    hadithReference: HADITH_BOOKS[0],
  };

  it('refuses a book the admin did not assign to the student', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await expect(
      service.create({ ...hadithDto, hadithReference: HADITH_BOOKS[1] } as any),
    ).rejects.toMatchObject({
      response: { code: MEMORIZATION_ERROR.HADITH_BOOK_NOT_ASSIGNED },
    });
    expect(prisma.memorizationProgress.create).not.toHaveBeenCalled();
  });

  // Entries typed as free text before the book list existed name no book;
  // correcting their amount must not be blocked by the assignment check.
  it('lets an edit keep a legacy free-text reference', async () => {
    const prisma = makePrisma();
    const service = new MemorizationService(prisma as any);

    await service.update(20, { amountDone: 2 } as any);

    expect(prisma.memorizationProgress.update).toHaveBeenCalled();
  });

  it('refuses an edit that moves the entry to an unassigned book', async () => {
    const prisma = makePrisma();
    const service = new MemorizationService(prisma as any);

    await expect(
      service.update(20, { hadithReference: HADITH_BOOKS[2] } as any),
    ).rejects.toMatchObject({
      response: { code: MEMORIZATION_ERROR.HADITH_BOOK_NOT_ASSIGNED },
    });
  });

  it('records a hadith entry for a student with hadith enabled', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await service.create(hadithDto as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('refuses a hadith entry with no hadithReference', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await expect(
      service.create({ ...hadithDto, hadithReference: '' } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses a hadith entry for a student without hadith enabled', async () => {
    const prisma = makePrisma({
      attendanceStatus: AttendanceStatus.PRESENT,
      tracksHadith: false,
    });
    const service = new MemorizationService(prisma as any);

    await expect(service.create(hadithDto as any)).rejects.toMatchObject({
      response: { code: MEMORIZATION_ERROR.HADITH_NOT_ENABLED },
    });
    expect(prisma.memorizationProgress.create).not.toHaveBeenCalled();
  });

  it('refuses a hadith entry carrying a surahNumber', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await expect(
      service.create({ ...hadithDto, surahNumber: 2 } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses a Quran entry carrying a hadithReference', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await expect(
      service.create({
        studentId: 7,
        surahNumber: 2,
        amountDone: 1,
        memorizationType: Memorization.MEMORIZING,
        hadithReference: 'حديث النية',
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('bounds a hadith amount at 50', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await expect(
      service.create({ ...hadithDto, amountDone: 51 } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('defaults an omitted subject to Quran without checking hadith eligibility', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    const service = new MemorizationService(prisma as any);

    await service.create({
      studentId: 7,
      surahNumber: 2,
      amountDone: 1,
      memorizationType: Memorization.MEMORIZING,
    } as any);

    expect(prisma.student.findUnique).not.toHaveBeenCalled();
    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });
});

describe('MemorizationService.getStudentProgress subject scoping', () => {
  const record = (over: Partial<Record<string, unknown>>) => ({
    id: 1,
    studentId: 7,
    surahNumber: null,
    amountDone: 1,
    memorizationType: Memorization.MEMORIZING,
    subject: MemorizationSubject.QURAN,
    hadithReference: null,
    recordedAt: new Date(),
    ...over,
  });

  it('keeps hadith rows out of totalPagesDone and totalSurahs, and sums them into totalHadithsDone', async () => {
    const prisma = {
      memorizationProgress: {
        findMany: jest.fn().mockResolvedValue([
          record({
            surahNumber: 2,
            amountDone: 3,
            subject: MemorizationSubject.QURAN,
          }),
          record({
            surahNumber: null,
            amountDone: 5,
            subject: MemorizationSubject.HADITH,
            hadithReference: 'حديث النية',
          }),
        ]),
      },
    };
    const service = new MemorizationService(prisma as any);

    const progress = await service.getStudentProgress(7);

    expect(progress.totalPagesDone).toBe(3);
    expect(progress.totalSurahs).toBe(1);
    expect(progress.totalHadithsDone).toBe(5);
  });
});
