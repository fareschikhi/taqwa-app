import {
  AttendanceStatus,
  Memorization,
  Prisma,
  ProgressUnit,
} from '@prisma/client';
import { reconcileDayPoints } from './day-points';
import { POINTS_START_DATE } from './points-rules';

// Dates are counted from POINTS_START_DATE, never written out, so moving the
// start date to release day never breaks these tests.
const fromStart = (days: number) =>
  new Date(new Date(POINTS_START_DATE).getTime() + days * 86_400_000);
const D = fromStart(3);

type Row = { id: number; source: string; amount: Prisma.Decimal };

const makeTx = (opts: {
  role?: string | null;
  attendance?: { status: AttendanceStatus; justification: { id: number } | null } | null;
  recitations?: Array<{
    memorizationType: Memorization;
    amountDone: number;
    unit?: ProgressUnit;
  }>;
  existing?: Row[];
}) => ({
  student: {
    findUnique: jest
      .fn()
      .mockResolvedValue(
        opts.role === null
          ? null
          : { userId: 70, user: { role: opts.role ?? 'STUDENT' } },
      ),
  },
  attendance: { findUnique: jest.fn().mockResolvedValue(opts.attendance ?? null) },
  memorizationProgress: {
    // The column is NOT NULL, so a stored row always has a unit; a test that
    // doesn't name one means a page.
    findMany: jest.fn().mockResolvedValue(
      (opts.recitations ?? []).map((r) => ({ unit: ProgressUnit.PAGE, ...r })),
    ),
  },
  pointEntry: {
    findMany: jest.fn().mockResolvedValue(opts.existing ?? []),
    create: jest.fn().mockResolvedValue({}),
    update: jest.fn().mockResolvedValue({}),
    deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
  },
});

const run = (tx: ReturnType<typeof makeTx>, date = D) =>
  reconcileDayPoints(tx as any, 7, date);

const present = { status: AttendanceStatus.PRESENT, justification: null };
const absent = { status: AttendanceStatus.ABSENT, justification: null };
const dec = (v: string) => new Prisma.Decimal(v);

describe('reconcileDayPoints', () => {
  it('does nothing before the start date', async () => {
    const tx = makeTx({ attendance: present });
    await run(tx, fromStart(-32));
    expect(tx.student.findUnique).not.toHaveBeenCalled();
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
  });

  it('ignores users who are not students', async () => {
    const tx = makeTx({ role: 'TEACHER', attendance: present });
    await run(tx);
    expect(tx.pointEntry.findMany).not.toHaveBeenCalled();
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
  });

  it('ignores a missing student', async () => {
    const tx = makeTx({ role: null, attendance: present });
    await run(tx);
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
  });

  it('gives adult students points too', async () => {
    const tx = makeTx({ role: 'ADULT_STUDENT', attendance: present });
    await run(tx);
    expect(tx.pointEntry.create).toHaveBeenCalledTimes(2);
  });

  it('creates PRESENT and MISSED for a present day with no recitation', async () => {
    const tx = makeTx({ attendance: present });
    await run(tx);
    expect(tx.pointEntry.create).toHaveBeenCalledWith({
      data: { userId: 70, amount: '0.500', source: 'PRESENT', date: D },
    });
    expect(tx.pointEntry.create).toHaveBeenCalledWith({
      data: {
        userId: 70,
        amount: '-1.000',
        source: 'MISSED_MEMORIZATION',
        date: D,
      },
    });
  });

  it('asks only for automatic rows', async () => {
    const tx = makeTx({ attendance: present });
    await run(tx);
    expect(tx.pointEntry.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { userId: 70, date: D, source: { not: 'MANUAL' } },
      }),
    );
  });

  it('is idempotent', async () => {
    const tx = makeTx({
      attendance: present,
      existing: [
        { id: 1, source: 'PRESENT', amount: dec('0.5') },
        { id: 2, source: 'MISSED_MEMORIZATION', amount: dec('-1') },
      ],
    });
    await run(tx);
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
    expect(tx.pointEntry.update).not.toHaveBeenCalled();
    expect(tx.pointEntry.deleteMany).not.toHaveBeenCalled();
  });

  it('swaps rows when present becomes absent', async () => {
    const tx = makeTx({
      attendance: absent,
      existing: [
        { id: 1, source: 'PRESENT', amount: dec('0.5') },
        { id: 2, source: 'MISSED_MEMORIZATION', amount: dec('-1') },
      ],
    });
    await run(tx);
    expect(tx.pointEntry.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [1, 2] } },
    });
    expect(tx.pointEntry.create).toHaveBeenCalledTimes(1);
    expect(tx.pointEntry.create).toHaveBeenCalledWith({
      data: { userId: 70, amount: '-1.000', source: 'ABSENCE', date: D },
    });
  });

  it('keeps the amount an attendance row was created with', async () => {
    const tx = makeTx({
      attendance: present,
      recitations: [{ memorizationType: Memorization.MEMORIZING, amountDone: 1 }],
      existing: [
        { id: 1, source: 'PRESENT', amount: dec('1') },
        { id: 2, source: 'MEMORIZATION', amount: dec('1') },
      ],
    });
    await run(tx);
    expect(tx.pointEntry.update).not.toHaveBeenCalled();
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
  });

  // The unit must be read with the recitation, or every hadith would be
  // priced as a page.
  it('prices a hadith-counted recitation by the hadith rate', async () => {
    const tx = makeTx({
      recitations: [
        {
          memorizationType: Memorization.MEMORIZING,
          amountDone: 3,
          unit: ProgressUnit.HADITH,
        },
      ],
    });
    await run(tx);
    expect(tx.memorizationProgress.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        select: expect.objectContaining({ unit: true }),
      }),
    );
    expect(tx.pointEntry.create).toHaveBeenCalledWith({
      data: { userId: 70, amount: '1.500', source: 'MEMORIZATION', date: D },
    });
  });

  it('updates the memorization row when pages change', async () => {
    const tx = makeTx({
      attendance: present,
      recitations: [{ memorizationType: Memorization.MEMORIZING, amountDone: 2 }],
      existing: [
        { id: 1, source: 'PRESENT', amount: dec('0.5') },
        { id: 2, source: 'MEMORIZATION', amount: dec('1') },
      ],
    });
    await run(tx);
    expect(tx.pointEntry.update).toHaveBeenCalledWith({
      where: { id: 2 },
      data: { amount: '2.000' },
    });
  });

  it('does not rewrite an unchanged memorization row', async () => {
    const tx = makeTx({
      attendance: present,
      recitations: [
        { memorizationType: Memorization.BIGREVISION, amountDone: 0.5 },
      ],
      existing: [
        { id: 1, source: 'PRESENT', amount: dec('0.5') },
        { id: 2, source: 'MEMORIZATION', amount: dec('0.1') },
      ],
    });
    await run(tx);
    expect(tx.pointEntry.update).not.toHaveBeenCalled();
  });

  it('removes memorization points when the recitations are gone', async () => {
    const tx = makeTx({
      attendance: absent,
      existing: [{ id: 5, source: 'MEMORIZATION', amount: dec('2') }],
    });
    await run(tx);
    expect(tx.pointEntry.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [5] } },
    });
  });

  it('drops the absence entry once a justification is recorded', async () => {
    const tx = makeTx({
      attendance: { status: AttendanceStatus.ABSENT, justification: { id: 9 } },
      existing: [{ id: 3, source: 'ABSENCE', amount: dec('-1') }],
    });
    await run(tx);
    expect(tx.pointEntry.deleteMany).toHaveBeenCalledWith({
      where: { id: { in: [3] } },
    });
    expect(tx.pointEntry.create).not.toHaveBeenCalled();
  });
});
