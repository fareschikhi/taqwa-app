import { AttendanceStatus } from '@prisma/client';
import { AttendanceService } from './attendance.service';
import { desiredCharges } from './fine-reconciliation';

/// Most of these tests predate notifications and do not exercise them, so they
/// take a stub rather than repeating the second constructor argument.
const svc = (prisma: unknown) =>
  new AttendanceService(prisma as any, { create: jest.fn() } as any);

describe('AttendanceService memorization cleanup', () => {
  const makePrisma = () => {
    const tx = {
      attendance: {
        // The service reads the prior status before writing, so a mock without
        // this throws before it reaches the behaviour under test.
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest
          .fn()
          .mockImplementation(({ create }) => Promise.resolve({ id: 1, ...create })),
        update: jest.fn().mockResolvedValue({
          id: 1,
          studentId: 7,
          date: new Date('2026-08-26'),
          status: AttendanceStatus.ABSENT,
          missedMemorization: false,
        }),
      },
      memorizationProgress: { deleteMany: jest.fn().mockResolvedValue({ count: 1 }) },
      // Not what this describe block is about — reconcileFines resolves no
      // student here, so it stays a no-op and never touches the fine tables.
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    const prisma = {
      $transaction: jest.fn((cb: any) => cb(tx)),
      tx,
    };
    return prisma;
  };

  const dto = (status: AttendanceStatus) => ({
    studentId: 7,
    date: '2026-08-26',
    status,
  });

  it('deletes that date\'s memorization when a student is marked absent', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.create(dto(AttendanceStatus.ABSENT));

    expect(prisma.tx.memorizationProgress.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 7, date: new Date('2026-08-26') },
    });
  });

  it('deletes in the same transaction as the attendance write', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.create(dto(AttendanceStatus.ABSENT));

    expect(prisma.$transaction).toHaveBeenCalled();
  });

  it('keeps memorization when the student is marked present', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.create(dto(AttendanceStatus.PRESENT));

    expect(prisma.tx.memorizationProgress.deleteMany).not.toHaveBeenCalled();
  });

  it('keeps memorization when the student is marked late', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.create(dto(AttendanceStatus.LATE));

    expect(prisma.tx.memorizationProgress.deleteMany).not.toHaveBeenCalled();
  });

  // The teacher marks a whole halaqa and saves it in one batch, so this is the
  // path nearly every absence now arrives through. Cleaning up only on the
  // single-record route would leave recitation standing for a batched absence.
  it('cleans up each absent student in a batch, and only those', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.createBatch({
      records: [
        { studentId: 7, date: '2026-08-26', status: AttendanceStatus.ABSENT },
        { studentId: 8, date: '2026-08-26', status: AttendanceStatus.PRESENT },
        { studentId: 9, date: '2026-08-26', status: AttendanceStatus.ABSENT },
      ],
    });

    expect(prisma.tx.memorizationProgress.deleteMany).toHaveBeenCalledTimes(2);
    expect(prisma.tx.memorizationProgress.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 7, date: new Date('2026-08-26') },
    });
    expect(prisma.tx.memorizationProgress.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 9, date: new Date('2026-08-26') },
    });
    expect(prisma.tx.memorizationProgress.deleteMany).not.toHaveBeenCalledWith({
      where: { studentId: 8, date: new Date('2026-08-26') },
    });
  });

  it('batches the whole save into one transaction', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.createBatch({
      records: [
        { studentId: 7, date: '2026-08-26', status: AttendanceStatus.ABSENT },
        { studentId: 8, date: '2026-08-26', status: AttendanceStatus.ABSENT },
      ],
    });

    // One save, one transaction: a partial write would leave the halaqa split
    // between saved and unsaved with nothing on screen saying which.
    expect(prisma.$transaction).toHaveBeenCalledTimes(1);
  });

  it('also cleans up when a PATCH flips an existing row to absent', async () => {
    const prisma = makePrisma();
    const service = svc(prisma as any);

    await service.update(1, { status: AttendanceStatus.ABSENT });

    expect(prisma.tx.memorizationProgress.deleteMany).toHaveBeenCalledWith({
      where: { studentId: 7, date: new Date('2026-08-26') },
    });
  });
});

describe('AttendanceService.getStudentAttendanceSummary', () => {
  /**
   * Counts are answered from the `where` clause, so the tests describe the
   * data rather than the call order: a row is "this month" only if the query
   * carried a date window.
   */
  const makePrisma = (rows: {
    present: number;
    absent: number;
    late: number;
    monthPresent: number;
    monthAbsent: number;
    monthLate: number;
  }) => ({
    attendance: {
      count: jest.fn(({ where }: any) => {
        const scoped = where.date !== undefined;
        if (where.status === 'PRESENT') {
          return Promise.resolve(scoped ? rows.monthPresent : rows.present);
        }
        if (where.status === 'ABSENT') {
          return Promise.resolve(scoped ? rows.monthAbsent : rows.absent);
        }
        if (where.status === 'LATE') {
          return Promise.resolve(scoped ? rows.monthLate : rows.late);
        }
        return Promise.resolve(rows.present + rows.absent + rows.late);
      }),
      // The summary also walks the records for the streak; these tests are
      // about the counts, so there is nothing to walk.
      findMany: jest.fn().mockResolvedValue([]),
    },
  });

  const counts = {
    present: 6,
    absent: 3,
    late: 1,
    monthPresent: 2,
    monthAbsent: 1,
    monthLate: 0,
  };

  it('keeps the all-time breakdown the history page reads', async () => {
    const service = svc(makePrisma(counts) as any);

    const summary = await service.getStudentAttendanceSummary(7);

    expect(summary).toMatchObject({
      present: 6,
      absent: 3,
      late: 1,
      total: 10,
      // 6 present + 1 late of 10 days: the late day counts as attendance.
      rate: 70,
    });
  });

  it('reports this month separately from all time', async () => {
    const service = svc(makePrisma(counts) as any);

    const summary = await service.getStudentAttendanceSummary(7);

    // 2 of 3 this month, against 7 of 10 overall.
    expect(summary.monthPresent).toBe(2);
    expect(summary.monthAbsent).toBe(1);
    expect(summary.monthLate).toBe(0);
    expect(summary.monthRate).toBe(67);
  });

  it('scopes the month counts to a UTC window over the current month', async () => {
    const prisma = makePrisma(counts);
    const service = svc(prisma as any);

    await service.getStudentAttendanceSummary(7);

    const scoped = prisma.attendance.count.mock.calls
      .map(([arg]: any) => arg.where)
      .filter((w: any) => w.date !== undefined);

    expect(scoped).toHaveLength(3);
    for (const where of scoped) {
      const { gte, lte } = where.date;
      // A local-time window would sit hours off the UTC-midnight date column
      // and drop the first or last day of the month.
      expect(gte.getUTCDate()).toBe(1);
      expect(gte.getUTCHours()).toBe(0);
      expect(lte.getUTCMonth()).toBe(gte.getUTCMonth());
      expect(lte.getTime()).toBeGreaterThan(gte.getTime());
    }
  });

  it('reports a month with no attendance as zero rather than dividing by it', async () => {
    const service = svc(
      makePrisma({
        ...counts,
        monthPresent: 0,
        monthAbsent: 0,
        monthLate: 0,
      }) as any,
    );

    const summary = await service.getStudentAttendanceSummary(7);

    expect(summary.monthRate).toBe(0);
  });

  it('counts a late day as attendance, not as an absence', async () => {
    // Turning up late is turning up. A month of nothing but late arrivals is
    // full attendance, and one absence among them is the only thing that
    // pulls the figure down.
    const service = svc(
      makePrisma({
        present: 0,
        absent: 0,
        late: 9,
        monthPresent: 0,
        monthAbsent: 0,
        monthLate: 9,
      }) as any,
    );

    const summary = await service.getStudentAttendanceSummary(7);

    expect(summary.monthRate).toBe(100);
    expect(summary.rate).toBe(100);
  });

  it('holds only absences against the month rate', async () => {
    const service = svc(
      makePrisma({
        present: 1,
        absent: 1,
        late: 2,
        monthPresent: 1,
        monthAbsent: 1,
        monthLate: 2,
      }) as any,
    );

    const summary = await service.getStudentAttendanceSummary(7);

    // 1 present + 2 late attended, 1 absent: 3 of 4.
    expect(summary.monthRate).toBe(75);
  });
});

describe('AttendanceService.getWeeklyAttendanceRates', () => {
  const DAY_MS = 24 * 60 * 60 * 1000;

  /** Sunday of the week the given date falls in, at UTC midnight. */
  const sundayOf = (d: Date) => {
    const utc = Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
    return new Date(utc - new Date(utc).getUTCDay() * DAY_MS);
  };

  /** rows: [dayOffsetFromSunday, status, count] */
  const makePrisma = (rows: Array<[number, string, number]>) => {
    const sunday = sundayOf(new Date());
    return {
      attendance: {
        groupBy: jest.fn(() =>
          Promise.resolve(
            rows.map(([offset, status, count]) => ({
              date: new Date(sunday.getTime() + offset * DAY_MS),
              status,
              _count: { _all: count },
            })),
          ),
        ),
      },
    };
  };

  it('reports the five school days of the week, Sunday first', async () => {
    const service = svc(makePrisma([]) as any);

    const week = await service.getWeeklyAttendanceRates();

    expect(week).toHaveLength(5);
    const sunday = sundayOf(new Date());
    expect(week[0].date).toBe(sunday.toISOString().slice(0, 10));
    expect(week[4].date).toBe(
      new Date(sunday.getTime() + 4 * DAY_MS).toISOString().slice(0, 10),
    );
  });

  it('counts late arrivals as attendance, the same as everywhere else', async () => {
    const service = svc(
      makePrisma([
        [0, 'PRESENT', 6],
        [0, 'LATE', 2],
        [0, 'ABSENT', 2],
      ]) as any,
    );

    const week = await service.getWeeklyAttendanceRates();

    // 6 present + 2 late of 10 marked.
    expect(week[0]).toMatchObject({ present: 8, absent: 2, rate: 80 });
  });

  it('leaves an unmarked day null instead of calling it 0%', async () => {
    // A day with no register taken is not a day everyone missed, and a 0% bar
    // on the dashboard would read as exactly that.
    const service = svc(
      makePrisma([[1, 'PRESENT', 4]]) as any,
    );

    const week = await service.getWeeklyAttendanceRates();

    expect(week[0].rate).toBeNull();
    expect(week[0].present).toBe(0);
    expect(week[1].rate).toBe(100);
  });

  it('keeps each day separate rather than pooling the week', async () => {
    const service = svc(
      makePrisma([
        [0, 'PRESENT', 1],
        [0, 'ABSENT', 3],
        [2, 'PRESENT', 3],
        [2, 'ABSENT', 1],
      ]) as any,
    );

    const week = await service.getWeeklyAttendanceRates();

    expect(week[0].rate).toBe(25);
    expect(week[2].rate).toBe(75);
  });

  it('asks the database only for that week', async () => {
    const prisma = makePrisma([]);
    const service = svc(prisma as any);

    await service.getWeeklyAttendanceRates();

    // The mock takes no declared parameters, so Jest records each call as a
    // zero-length tuple; the cast is what lets the recorded argument be read.
    const calls = prisma.attendance.groupBy.mock.calls as unknown as Array<
      [any]
    >;
    const { where } = calls[0][0];
    const sunday = sundayOf(new Date());
    expect(where.date.gte.getTime()).toBe(sunday.getTime());
    expect(where.date.lte.getTime()).toBe(sunday.getTime() + 4 * DAY_MS);
  });
});

describe('AttendanceService notifications', () => {
  // The three write paths are upserts wrapped in a transaction. The mock runs
  // the callback with a client whose findUnique reports what the row held
  // before, which is what tells a real change from a re-save.
  const makePrisma = (opts: {
    previous?: string | null;
    parentUserId?: number | null;
  }) => {
    const tx = {
      attendance: {
        findUnique: jest
          .fn()
          .mockResolvedValue(
            opts.previous == null ? null : { status: opts.previous },
          ),
        upsert: jest.fn().mockResolvedValue({ id: 1 }),
      },
      memorizationProgress: { deleteMany: jest.fn() },
      // Distinct from the top-level `student` below, which answers the
      // post-commit notification lookup. reconcileFines runs inside the
      // transaction and resolves no student here, so it is a no-op.
      student: { findUnique: jest.fn().mockResolvedValue(null) },
    };
    return {
      $transaction: jest.fn((cb: any) => cb(tx)),
      student: {
        findUnique: jest.fn().mockResolvedValue(
          opts.parentUserId == null
            ? { parentId: null, user: { fullName: 'Bilal' } }
            : {
                parentId: 1,
                user: { fullName: 'Bilal' },
                parent: { userId: opts.parentUserId },
              },
        ),
      },
      tx,
    };
  };

  const makeService = (prisma: any, notifications: any) =>
    new AttendanceService(prisma as any, notifications as any);

  const notificationsMock = () => ({ create: jest.fn().mockResolvedValue({}) });

  it('notifies the parent when a student becomes absent', async () => {
    const prisma = makePrisma({ previous: 'PRESENT', parentUserId: 9 });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.ABSENT);

    expect(notifications.create).toHaveBeenCalledWith({
      userId: 9,
      title: 'غياب',
      body: 'تم تسجيل غياب Bilal اليوم',
    });
  });

  it('uses the late wording for a late arrival', async () => {
    const prisma = makePrisma({ previous: 'PRESENT', parentUserId: 9 });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.LATE);

    expect(notifications.create).toHaveBeenCalledWith({
      userId: 9,
      title: 'تأخر',
      body: 'تم تسجيل تأخر Bilal اليوم',
    });
  });

  it('notifies on a brand new row', async () => {
    const prisma = makePrisma({ previous: null, parentUserId: 9 });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.ABSENT);

    expect(notifications.create).toHaveBeenCalledTimes(1);
  });

  it('says nothing when the status did not change', async () => {
    const prisma = makePrisma({ previous: 'ABSENT', parentUserId: 9 });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.ABSENT);

    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('says nothing when a student turns up', async () => {
    const prisma = makePrisma({ previous: 'ABSENT', parentUserId: 9 });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.PRESENT);

    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('skips a student with no parent', async () => {
    const prisma = makePrisma({ previous: 'PRESENT', parentUserId: null });
    const notifications = notificationsMock();
    const service = makeService(prisma, notifications);

    await service.upsert(2, '2026-08-29', AttendanceStatus.ABSENT);

    expect(notifications.create).not.toHaveBeenCalled();
  });

  it('keeps the attendance record when notifying fails', async () => {
    const prisma = makePrisma({ previous: 'PRESENT', parentUserId: 9 });
    const notifications = {
      create: jest.fn().mockRejectedValue(new Error('down')),
    };
    const service = makeService(prisma, notifications);

    // The write is already committed, so this must resolve rather than throw.
    await expect(
      service.upsert(2, '2026-08-29', AttendanceStatus.ABSENT),
    ).resolves.toBeDefined();
    expect(prisma.tx.attendance.upsert).toHaveBeenCalled();
  });
});

describe('AttendanceService guardian notifications', () => {
  const makeService = (student: Record<string, unknown>) => {
    const tx = {
      attendance: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockImplementation(({ create }) => ({ id: 1, ...create })),
      },
      memorizationProgress: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
      student: { findUnique: jest.fn().mockResolvedValue({ user: { role: 'STUDENT' }, halaqa: null }) },
      fineEntry: {
        findMany: jest.fn().mockResolvedValue([]),
        deleteMany: jest.fn(),
        create: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((cb: any) => cb(tx)),
      student: { findUnique: jest.fn().mockResolvedValue(student) },
    };
    const notifications = { create: jest.fn().mockResolvedValue(undefined) };
    return {
      service: new AttendanceService(prisma as any, notifications as any),
      notifications,
    };
  };

  it('notifies the parent of a child student', async () => {
    const { service, notifications } = makeService({
      userId: 30,
      parentId: 4,
      user: { fullName: 'Bilal Cherguini', role: 'STUDENT' },
      parent: { userId: 12 },
    });

    await service.create({
      studentId: 7,
      date: '2026-08-26',
      status: AttendanceStatus.ABSENT,
    } as any);

    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 12 }),
    );
  });

  // He has no parent row at all, so the old lookup returned nothing and he
  // heard about none of his own absences.
  it('notifies an adult student on his own account', async () => {
    const { service, notifications } = makeService({
      userId: 11,
      parentId: null,
      user: { fullName: 'Yacine Belkacem', role: 'ADULT_STUDENT' },
      parent: null,
    });

    await service.create({
      studentId: 21,
      date: '2026-08-26',
      status: AttendanceStatus.ABSENT,
    } as any);

    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({ userId: 11 }),
    );
  });

  // reconcileFines runs inside the transaction and returns what it charged;
  // notifyGuardians must fold that amount into the same notification rather
  // than dropping it, since a separate fine alert would be a second ping for
  // one event.
  it('appends the fee when the absence carried a charge', async () => {
    const tx = {
      attendance: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn().mockImplementation(({ create }) => ({ id: 1, ...create })),
      },
      memorizationProgress: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
      student: {
        findUnique: jest.fn().mockResolvedValue({
          userId: 11,
          user: { role: 'ADULT_STUDENT' },
          halaqa: {
            isAdult: true,
            absenceFee: 500,
            lateFee: 200,
            missedMemorizationFee: 100,
          },
        }),
      },
      fineEntry: {
        findMany: jest.fn().mockResolvedValue([]),
        deleteMany: jest.fn(),
        create: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((cb: any) => cb(tx)),
      student: {
        findUnique: jest.fn().mockResolvedValue({
          userId: 11,
          parentId: null,
          user: { fullName: 'Yacine Belkacem', role: 'ADULT_STUDENT' },
          parent: null,
        }),
      },
    };
    const notifications = { create: jest.fn().mockResolvedValue(undefined) };
    const service = new AttendanceService(prisma as any, notifications as any);

    await service.create({
      studentId: 21,
      date: '2026-08-26',
      status: AttendanceStatus.ABSENT,
    } as any);

    expect(notifications.create).toHaveBeenCalledWith(
      expect.objectContaining({ body: 'تم تسجيل غيابك اليوم — رسوم 500 دج' }),
    );
  });

  it('names the child rather than charging a fee when the same student has a parent', async () => {
    const { service, notifications } = makeService({
      userId: 30,
      parentId: 4,
      user: { fullName: 'Bilal Cherguini', role: 'STUDENT' },
      parent: { userId: 12 },
    });

    await service.create({
      studentId: 7,
      date: '2026-08-26',
      status: AttendanceStatus.LATE,
    } as any);

    expect(notifications.create).toHaveBeenCalledWith({
      userId: 12,
      title: 'تأخر',
      body: 'تم تسجيل تأخر Bilal Cherguini اليوم',
    });
  });
});

describe('AttendanceService attendance streak', () => {
  /// The streak is the run of attended days ending at the most recent record.
  /// LATE continues it: the same rule the rate already applies, so the two
  /// figures on the parent's screen cannot disagree about the same week.
  const makePrisma = (statuses: string[]) => ({
    attendance: {
      count: jest.fn().mockResolvedValue(0),
      // Newest first, which is the order the streak walks.
      findMany: jest
        .fn()
        .mockResolvedValue(statuses.map((status) => ({ status }))),
    },
  });

  const streakOf = async (statuses: string[]) => {
    const service = svc(makePrisma(statuses));
    const summary = await service.getStudentAttendanceSummary(7);
    return summary.currentStreak;
  };

  it('counts an unbroken run of attendance', async () => {
    expect(await streakOf(['PRESENT', 'PRESENT', 'PRESENT'])).toBe(3);
  });

  it('stops at the first absence', async () => {
    expect(await streakOf(['PRESENT', 'PRESENT', 'ABSENT', 'PRESENT'])).toBe(2);
  });

  it('keeps counting through a late arrival', async () => {
    expect(await streakOf(['PRESENT', 'LATE', 'PRESENT'])).toBe(3);
  });

  it('counts only the most recent run, not the longest', async () => {
    // Four in a row earlier does not help a student absent yesterday.
    expect(
      await streakOf(['ABSENT', 'PRESENT', 'PRESENT', 'PRESENT', 'PRESENT']),
    ).toBe(0);
  });

  it('is zero for a student with no attendance at all', async () => {
    expect(await streakOf([])).toBe(0);
  });

  it('reads the records newest first', async () => {
    const prisma = makePrisma(['PRESENT']);
    const service = svc(prisma);

    await service.getStudentAttendanceSummary(7);

    const { orderBy, where } = prisma.attendance.findMany.mock.calls[0][0];
    expect(where).toEqual({ studentId: 7 });
    expect(orderBy).toEqual({ date: 'desc' });
  });
});

describe('AttendanceService fine reconciliation', () => {
  const makePrisma = (opts: {
    role?: string;
    isAdult?: boolean;
    existing?: Array<{ id: number; source: string }>;
  } = {}) => {
    const tx = {
      attendance: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest
          .fn()
          .mockImplementation(({ create }) =>
            Promise.resolve({ id: 1, ...create }),
          ),
      },
      memorizationProgress: { deleteMany: jest.fn().mockResolvedValue({ count: 0 }) },
      student: {
        // userId stands in for the fallback createdById: reconcileFines uses
        // it only when no actor is passed in, which is exactly what create()
        // does here since these tests call it with two arguments.
        findUnique: jest.fn().mockResolvedValue({
          userId: 30,
          user: { role: opts.role ?? 'ADULT_STUDENT' },
          halaqa: (opts.isAdult ?? true)
            ? {
                isAdult: true,
                absenceFee: 50,
                lateFee: 20,
                missedMemorizationFee: 30,
              }
            : null,
        }),
      },
      fineEntry: {
        findMany: jest.fn().mockResolvedValue(opts.existing ?? []),
        deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
        create: jest.fn().mockResolvedValue({ id: 100 }),
      },
    };
    return { $transaction: jest.fn((cb: any) => cb(tx)), tx };
  };

  const svcWith = (prisma: unknown) =>
    new AttendanceService(prisma as any, { create: jest.fn() } as any);

  const dto = (status: AttendanceStatus, missedMemorization = false) => ({
    studentId: 7,
    date: '2026-08-26',
    status,
    missedMemorization,
  });

  it('charges an absent adult student the halaqa absence fee', async () => {
    const prisma = makePrisma();
    await svcWith(prisma).create(dto(AttendanceStatus.ABSENT));

    expect(prisma.tx.fineEntry.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          studentId: 7,
          kind: 'CHARGE',
          source: 'ABSENCE',
          amount: 50,
        }),
      }),
    );
  });

  // The teacher's sheet re-saves the same day on every tap. The row is already
  // there, so the second save must add nothing.
  it('does not charge twice when the same day is saved again', async () => {
    const prisma = makePrisma({ existing: [{ id: 100, source: 'ABSENCE' }] });
    await svcWith(prisma).create(dto(AttendanceStatus.ABSENT));

    expect(prisma.tx.fineEntry.create).not.toHaveBeenCalled();
  });

  it('withdraws the absence charge when the day is corrected to present', async () => {
    const prisma = makePrisma({ existing: [{ id: 100, source: 'ABSENCE' }] });
    await svcWith(prisma).create(dto(AttendanceStatus.PRESENT));

    expect(prisma.tx.fineEntry.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [100] } },
    });
    expect(prisma.tx.fineEntry.create).not.toHaveBeenCalled();
  });

  it('charges nothing for a child student', async () => {
    const prisma = makePrisma({ role: 'STUDENT' });
    await svcWith(prisma).create(dto(AttendanceStatus.ABSENT));

    expect(prisma.tx.fineEntry.create).not.toHaveBeenCalled();
  });

  it('charges nothing when the adult student has no halaqa', async () => {
    const prisma = makePrisma({ isAdult: false });
    await svcWith(prisma).create(dto(AttendanceStatus.ABSENT));

    expect(prisma.tx.fineEntry.create).not.toHaveBeenCalled();
  });

  it('charges the memorization fee for a present student who did not recite', async () => {
    const prisma = makePrisma();
    await svcWith(prisma).create(dto(AttendanceStatus.PRESENT, true));

    expect(prisma.tx.fineEntry.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ source: 'MISSED_MEMORIZATION', amount: 30 }),
      }),
    );
  });
});
