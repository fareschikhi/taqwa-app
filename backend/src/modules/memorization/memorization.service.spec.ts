jest.mock('../points/day-points', () => ({
  reconcileDayPoints: jest.fn().mockResolvedValue(undefined),
}));
import { reconcileDayPoints } from '../points/day-points';
import { BadRequestException } from '@nestjs/common';
import {
  AttendanceStatus,
  Memorization,
  MemorizationSubject,
  ProgressUnit,
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

  // Old app versions send no unit: a hadith entry then counts hadiths, as
  // every hadith entry did before the choice existed.
  it('stores an omitted hadith unit as HADITH', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await new MemorizationService(prisma as any).create(hadithDto as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ unit: ProgressUnit.HADITH }),
    });
  });

  it('records a hadith entry counted in half pages', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await new MemorizationService(prisma as any).create({
      ...hadithDto,
      unit: ProgressUnit.PAGE,
      amountDone: 1.5,
    } as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ unit: ProgressUnit.PAGE, amountDone: 1.5 }),
    });
  });

  it('allows more than 50 hadith pages, unlike single hadiths', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await new MemorizationService(prisma as any).create({
      ...hadithDto,
      unit: ProgressUnit.PAGE,
      amountDone: 60,
    } as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('refuses half a hadith', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await expect(
      new MemorizationService(prisma as any).create({
        ...hadithDto,
        unit: ProgressUnit.HADITH,
        amountDone: 1.5,
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses a Quran entry counted in hadiths', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await expect(
      new MemorizationService(prisma as any).create({
        studentId: 7,
        surahNumber: 2,
        amountDone: 1,
        unit: ProgressUnit.HADITH,
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('stores a Quran entry in pages', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await new MemorizationService(prisma as any).create({
      studentId: 7,
      surahNumber: 2,
      amountDone: 1,
    } as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ unit: ProgressUnit.PAGE }),
    });
  });

  it('lets an edit switch a hadith entry to pages', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    await new MemorizationService(prisma as any).update(20, {
      unit: ProgressUnit.PAGE,
      amountDone: 2.5,
    } as any);

    expect(prisma.memorizationProgress.update).toHaveBeenCalledWith({
      where: { id: 20 },
      data: expect.objectContaining({ unit: ProgressUnit.PAGE, amountDone: 2.5 }),
    });
  });

  it('keeps the stored unit when an edit only changes the amount', async () => {
    const prisma = makePrisma({ attendanceStatus: AttendanceStatus.PRESENT });
    prisma.memorizationProgress.findUnique.mockResolvedValue({
      id: 20,
      studentId: 7,
      subject: MemorizationSubject.HADITH,
      unit: ProgressUnit.PAGE,
      surahNumber: null,
      hadithReference: HADITH_BOOKS[0],
      memorizationType: Memorization.MEMORIZING,
      amountDone: 1,
    });
    await new MemorizationService(prisma as any).update(20, {
      amountDone: 0.5,
    } as any);

    expect(prisma.memorizationProgress.update).toHaveBeenCalledWith({
      where: { id: 20 },
      data: expect.objectContaining({ unit: ProgressUnit.PAGE, amountDone: 0.5 }),
    });
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

  // Hadiths and hadith pages are different units, so they get separate
  // totals instead of being added together.
  it('sums hadith pages apart from single hadiths', async () => {
    const prisma = {
      memorizationProgress: {
        findMany: jest.fn().mockResolvedValue([
          record({
            amountDone: 4,
            subject: MemorizationSubject.HADITH,
            unit: ProgressUnit.HADITH,
          }),
          record({
            amountDone: 2.5,
            subject: MemorizationSubject.HADITH,
            unit: ProgressUnit.PAGE,
          }),
          record({
            amountDone: 10,
            subject: MemorizationSubject.HADITH,
            unit: ProgressUnit.PAGE,
            memorizationType: Memorization.BIGREVISION,
          }),
        ]),
      },
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    const progress = await new MemorizationService(
      prisma as any,
    ).getStudentProgress(7);

    expect(progress.totalHadithsDone).toBe(4);
    expect(progress.totalHadithPagesDone).toBe(2.5);
    expect(progress.totalPagesDone).toBe(0);
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

describe('MemorizationService keeps daily points in step', () => {
  const points = jest.mocked(reconcileDayPoints);
  beforeEach(() => points.mockClear());

  const makePrisma = (attendance: AttendanceStatus | null) => {
    const prisma: any = {
      attendance: {
        findUnique: jest
          .fn()
          .mockResolvedValue(attendance === null ? null : { id: 1, status: attendance }),
      },
      memorizationProgress: {
        create: jest.fn().mockResolvedValue({ id: 10 }),
        findUnique: jest.fn().mockResolvedValue({
          id: 20,
          studentId: 7,
          date: new Date('2026-11-05'),
          subject: MemorizationSubject.QURAN,
          surahNumber: 2,
          hadithReference: null,
          memorizationType: Memorization.MEMORIZING,
          amountDone: 1,
        }),
        update: jest.fn().mockResolvedValue({ id: 20 }),
      },
      // A child: fine reconciliation is a no-op, keeping this about points.
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
  const today = () => {
    const now = new Date();
    return new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
    );
  };

  it('reconciles the day a recitation is recorded', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    await new MemorizationService(prisma).create(dto);
    expect(points).toHaveBeenCalledWith(prisma, 7, today());
  });

  it('reconciles points even before roll call', async () => {
    const prisma = makePrisma(null);
    await new MemorizationService(prisma).create(dto);
    expect(points).toHaveBeenCalledWith(prisma, 7, today());
  });

  it('reconciles the recitation\'s own day when it is edited', async () => {
    const prisma = makePrisma(null);
    await new MemorizationService(prisma).update(20, { amountDone: 3 } as any);
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(points).toHaveBeenCalledWith(prisma, 7, new Date('2026-11-05'));
    expect(points.mock.invocationCallOrder[0]).toBeGreaterThan(
      prisma.memorizationProgress.update.mock.invocationCallOrder[0],
    );
  });
});

describe('MemorizationService Quran ayah ranges', () => {
  const makePrisma = (existing?: Record<string, unknown>) => {
    const prisma: any = {
      attendance: {
        findUnique: jest
          .fn()
          .mockResolvedValue({ id: 1, status: AttendanceStatus.PRESENT }),
      },
      memorizationProgress: {
        create: jest.fn().mockResolvedValue({ id: 10 }),
        update: jest.fn().mockResolvedValue({ id: 20 }),
        findUnique: jest.fn().mockResolvedValue(existing ?? null),
      },
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    prisma.$transaction = jest.fn((cb: any) => cb(prisma));
    return prisma;
  };
  const ayahs = (over: Record<string, unknown> = {}) => ({
    studentId: 7,
    surahNumber: 2,
    unit: ProgressUnit.AYAH,
    ayahFrom: 1,
    ayahTo: 20,
    amountDone: 20,
    memorizationType: Memorization.MEMORIZING,
    ...over,
  });

  it('stores an ayah range with its count', async () => {
    const prisma = makePrisma();
    await new MemorizationService(prisma as any).create(ayahs() as any);

    expect(prisma.memorizationProgress.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        unit: ProgressUnit.AYAH,
        ayahFrom: 1,
        ayahTo: 20,
        amountDone: 20,
      }),
    });
  });

  it('accepts the whole of the longest surah', async () => {
    const prisma = makePrisma();
    await new MemorizationService(prisma as any).create(
      ayahs({ ayahTo: 286, amountDone: 286 }) as any,
    );
    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it.each([
    ['past the end of the surah', { surahNumber: 1, ayahFrom: 5, ayahTo: 8, amountDone: 4 }],
    ['backwards', { ayahFrom: 10, ayahTo: 5, amountDone: 6 }],
    ['without an end', { ayahTo: undefined }],
    ['without a surah', { surahNumber: undefined }],
    ['with an amount that is not the count', { amountDone: 19 }],
  ])('refuses a range %s', async (_label, over) => {
    const prisma = makePrisma();
    await expect(
      new MemorizationService(prisma as any).create(ayahs(over) as any),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.memorizationProgress.create).not.toHaveBeenCalled();
  });

  it('refuses a range on an entry counted in pages', async () => {
    const prisma = makePrisma();
    await expect(
      new MemorizationService(prisma as any).create(
        ayahs({ unit: ProgressUnit.PAGE, amountDone: 1 }) as any,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses a hadith entry counted in ayahs', async () => {
    const prisma = makePrisma();
    await expect(
      new MemorizationService(prisma as any).create(
        ayahs({
          subject: MemorizationSubject.HADITH,
          surahNumber: undefined,
          hadithReference: HADITH_BOOKS[0],
        }) as any,
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  const storedAyahRow = {
    id: 20,
    studentId: 7,
    subject: MemorizationSubject.QURAN,
    unit: ProgressUnit.AYAH,
    surahNumber: 2,
    ayahFrom: 1,
    ayahTo: 5,
    hadithReference: null,
    memorizationType: Memorization.MEMORIZING,
    amountDone: 5,
    date: new Date('2026-11-11'),
  };

  it('recounts the amount when an edit moves one end of the range', async () => {
    const prisma = makePrisma(storedAyahRow);
    await new MemorizationService(prisma as any).update(20, {
      ayahTo: 10,
    } as any);

    expect(prisma.memorizationProgress.update).toHaveBeenCalledWith({
      where: { id: 20 },
      data: expect.objectContaining({ ayahFrom: 1, ayahTo: 10, amountDone: 10 }),
    });
  });

  it('drops the range when an edit moves the entry to pages', async () => {
    const prisma = makePrisma(storedAyahRow);
    await new MemorizationService(prisma as any).update(20, {
      unit: ProgressUnit.PAGE,
      amountDone: 1,
    } as any);

    expect(prisma.memorizationProgress.update).toHaveBeenCalledWith({
      where: { id: 20 },
      data: expect.objectContaining({
        unit: ProgressUnit.PAGE,
        ayahFrom: null,
        ayahTo: null,
      }),
    });
  });

  it('refuses an edit that moves the surah under a range it cannot hold', async () => {
    const prisma = makePrisma({ ...storedAyahRow, ayahTo: 7, amountDone: 7 });
    await expect(
      new MemorizationService(prisma as any).update(20, {
        surahNumber: 108, // الكوثر: 3 ayahs
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  // Ayahs and pages are different units: an ayah entry adds to its own total
  // and never inflates the page count.
  it('totals ayahs apart from pages', async () => {
    const row = (over: Record<string, unknown>) => ({
      ...storedAyahRow,
      recordedAt: new Date(),
      ...over,
    });
    const prisma: any = {
      memorizationProgress: {
        findMany: jest.fn().mockResolvedValue([
          row({ unit: ProgressUnit.PAGE, ayahFrom: null, ayahTo: null, amountDone: 2 }),
          row({ amountDone: 5 }),
          row({ surahNumber: 3, amountDone: 12 }),
          // Revision re-reads what is already memorized.
          row({ memorizationType: Memorization.SMALLREVISION, amountDone: 40 }),
        ]),
      },
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    const progress = await new MemorizationService(prisma).getStudentProgress(7);

    expect(progress.totalPagesDone).toBe(2);
    expect(progress.totalAyahsDone).toBe(17);
    expect(progress.totalSurahs).toBe(2);
  });
});
