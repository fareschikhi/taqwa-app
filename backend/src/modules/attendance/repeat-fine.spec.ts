import { reconcileRepeatFine } from './repeat-fine';

const D = new Date('2026-11-13');

const makeTx = (opts: {
  role?: string;
  isAdult?: boolean;
  repeatFee?: number;
  repeats: number;
  existing?: { id: number; amount: number } | null;
}) => ({
  student: {
    findUnique: jest.fn().mockResolvedValue({
      userId: 30,
      user: { role: opts.role ?? 'ADULT_STUDENT' },
      halaqa: {
        isAdult: opts.isAdult ?? true,
        repeatFee: opts.repeatFee ?? 200,
      },
    }),
  },
  memorizationProgress: { count: jest.fn().mockResolvedValue(opts.repeats) },
  fineEntry: {
    findFirst: jest.fn().mockResolvedValue(opts.existing ?? null),
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
  },
});

describe('reconcileRepeatFine', () => {
  it('charges the fee once per repeat of the day, in one row', async () => {
    const tx = makeTx({ repeats: 2 });
    await reconcileRepeatFine(tx as any, 7, D, 5);

    expect(tx.memorizationProgress.count).toHaveBeenCalledWith({
      where: { studentId: 7, date: D, isRepeat: true },
    });
    expect(tx.fineEntry.create).toHaveBeenCalledWith({
      data: {
        studentId: 7,
        kind: 'CHARGE',
        amount: 400,
        source: 'REPEAT',
        date: D,
        createdById: 5,
      },
    });
  });

  it('moves the charge when a repeat is added the same day', async () => {
    const tx = makeTx({ repeats: 3, existing: { id: 9, amount: 400 } });
    await reconcileRepeatFine(tx as any, 7, D, null);

    expect(tx.fineEntry.update).toHaveBeenCalledWith({
      where: { id: 9 },
      data: { amount: 600 },
    });
    expect(tx.fineEntry.create).not.toHaveBeenCalled();
  });

  it('removes the charge once no repeat is left', async () => {
    const tx = makeTx({ repeats: 0, existing: { id: 9, amount: 200 } });
    await reconcileRepeatFine(tx as any, 7, D, null);

    expect(tx.fineEntry.delete).toHaveBeenCalledWith({ where: { id: 9 } });
  });

  it('charges nothing to a child', async () => {
    const tx = makeTx({ role: 'STUDENT', isAdult: false, repeats: 1 });
    await reconcileRepeatFine(tx as any, 7, D, null);

    expect(tx.fineEntry.create).not.toHaveBeenCalled();
    expect(tx.fineEntry.update).not.toHaveBeenCalled();
  });

  it('charges nothing in a halaqa whose repeat fee is 0', async () => {
    const tx = makeTx({ repeatFee: 0, repeats: 1 });
    await reconcileRepeatFine(tx as any, 7, D, null);

    expect(tx.fineEntry.create).not.toHaveBeenCalled();
  });

  // Turning the fee off later must not erase what was already charged.
  it('keeps an old charge when the fee was since set to 0', async () => {
    const tx = makeTx({
      repeatFee: 0,
      repeats: 1,
      existing: { id: 9, amount: 200 },
    });
    await reconcileRepeatFine(tx as any, 7, D, null);

    expect(tx.fineEntry.update).not.toHaveBeenCalled();
    expect(tx.fineEntry.delete).not.toHaveBeenCalled();
  });
});
