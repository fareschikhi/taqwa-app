import { BadRequestException } from '@nestjs/common';
import {
  AttendanceStatus,
  Memorization,
  MemorizationSubject,
} from '@prisma/client';
import { MEMORIZATION_ERROR, MemorizationService } from './memorization.service';
import { HADITH_BOOKS } from '../students/hadith-books';

describe('MemorizationService.create attendance gate', () => {
  const makePrisma = (status: AttendanceStatus | null) => {
    const prisma: any = {
      attendance: {
        findUnique: jest
          .fn()
          .mockResolvedValue(status === null ? null : { id: 1, status }),
      },
      memorizationProgress: {
        create: jest.fn().mockResolvedValue({ id: 10 }),
      },
      // A child student: the day's fine reconciliation is a no-op for him,
      // which keeps this block about the attendance gate alone.
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    prisma.$transaction = jest.fn((cb: any) => cb(prisma));
    return prisma;
  };

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

    // Revision is counted in pages, of which the mushaf has 604. The DTO's
    // coarse ceiling is not applied here, so the service is what refuses it.
    const tooMany = {
      ...dto,
      memorizationType: Memorization.SMALLREVISION,
      amountDone: 605,
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

/// "Did not memorize" is derived, so recording a recitation is what withdraws
/// the fee roll call put on an adult student.
describe('MemorizationService.create clears the missed-memorization fee', () => {
  const makePrisma = (attendance: AttendanceStatus | null) => {
    const prisma: any = {
      attendance: {
        findUnique: jest
          .fn()
          .mockResolvedValue(attendance === null ? null : { id: 1, status: attendance }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
      memorizationProgress: {
        create: jest.fn().mockResolvedValue({ id: 10 }),
        // The row just created inside the same transaction.
        count: jest.fn().mockResolvedValue(1),
      },
      student: {
        findUnique: jest.fn().mockResolvedValue({
          userId: 30,
          user: { role: 'ADULT_STUDENT' },
          halaqa: {
            isAdult: true,
            absenceFee: 50,
            lateFee: 20,
            missedMemorizationFee: 30,
          },
        }),
      },
      fineEntry: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ id: 99, source: 'MISSED_MEMORIZATION' }]),
        deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
        create: jest.fn(),
      },
    };
    prisma.$transaction = jest.fn((cb: any) => cb(prisma));
    return prisma;
  };

  const dto = {
    studentId: 7,
    surahNumber: 2,
    amountDone: 1,
    memorizationType: Memorization.MEMORIZING,
  };

  it('withdraws the day\'s missed-memorization charge', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    await new MemorizationService(prisma).create(dto);

    expect(prisma.fineEntry.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [99] } },
    });
    expect(prisma.attendance.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({ data: { missedMemorization: false } }),
    );
    expect(prisma.fineEntry.create).not.toHaveBeenCalled();
  });

  it('reconciles nothing before roll call has been taken', async () => {
    const prisma = makePrisma(null);
    await new MemorizationService(prisma).create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
    expect(prisma.fineEntry.findMany).not.toHaveBeenCalled();
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
    // Runs the callback against this same mock, as the real client would
    // against its transaction.
    $transaction: jest.fn(function (this: any, cb: any) {
      return cb(this);
    }),
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

    // The day's fine reconciliation reads the student too, so the check is on
    // the hadith-eligibility lookup specifically, not on any student read.
    expect(prisma.student.findUnique).not.toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({ tracksHadith: true }),
      }),
    );
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
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    const service = new MemorizationService(prisma as any);

    const progress = await service.getStudentProgress(7);

    expect(progress.totalPagesDone).toBe(3);
    expect(progress.totalSurahs).toBe(1);
    expect(progress.totalHadithsDone).toBe(5);
  });

  it('counts hadith rows by type separately from the Quran type counts', async () => {
    const prisma = {
      memorizationProgress: {
        findMany: jest.fn().mockResolvedValue([
          record({ memorizationType: Memorization.MEMORIZING }),
          record({
            surahNumber: null,
            subject: MemorizationSubject.HADITH,
            hadithReference: 'حديث النية',
            memorizationType: Memorization.MEMORIZING,
          }),
          record({
            surahNumber: null,
            subject: MemorizationSubject.HADITH,
            hadithReference: 'حديث النية',
            memorizationType: Memorization.BIGREVISION,
          }),
        ]),
      },
      student: {
        findUnique: jest.fn().mockResolvedValue({ tracksHadith: true }),
      },
    };
    const service = new MemorizationService(prisma as any);

    const progress = await service.getStudentProgress(7);

    expect(progress.typeCounts).toEqual({
      MEMORIZING: 1,
      SMALLREVISION: 0,
      BIGREVISION: 0,
    });
    expect(progress.hadithTypeCounts).toEqual({
      MEMORIZING: 1,
      SMALLREVISION: 0,
      BIGREVISION: 1,
    });
    expect(progress.tracksHadith).toBe(true);
  });
});

describe('MemorizationService half-page amounts', () => {
  const makeService = () => {
    const prisma = {
      attendance: { findUnique: jest.fn().mockResolvedValue(null) },
      memorizationProgress: {
        create: jest.fn().mockResolvedValue({ id: 10 }),
      },
      $transaction: jest.fn(function (this: any, cb: any) {
        return cb(this);
      }),
    };
    return { prisma, service: new MemorizationService(prisma as any) };
  };

  const pages = (amountDone: number) => ({
    studentId: 7,
    surahNumber: 2,
    amountDone,
    memorizationType: Memorization.MEMORIZING,
  });

  it.each([0.5, 1.5, 3.5, 10])('records %p pages of new memorization', async (amount) => {
    const { prisma, service } = makeService();
    await service.create(pages(amount));
    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it.each([1.3, 1.2, 2.25, 0.3])('refuses %p pages, which is not a half step', async (amount) => {
    const { service } = makeService();
    await expect(service.create(pages(amount))).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  // Revision is counted in pages too, so it takes the same half step.
  it.each([Memorization.SMALLREVISION, Memorization.BIGREVISION])(
    'records a half page of %s',
    async (memorizationType) => {
      const { prisma, service } = makeService();
      await service.create({ ...pages(1.5), memorizationType });
      expect(prisma.memorizationProgress.create).toHaveBeenCalled();
    },
  );

  it('records a whole hizb of revision as ten pages', async () => {
    const { prisma, service } = makeService();
    await service.create({
      ...pages(10),
      memorizationType: Memorization.BIGREVISION,
    });
    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });
});
