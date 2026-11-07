import { AttendanceStatus, Memorization } from '@prisma/client';

/// The first day that earns automatic points (UTC day, as attendance dates are
/// stored). Everyone starts at zero: days before it are never back-filled, even
/// when a recitation from back then is edited.
export const POINTS_START_DATE = '2026-11-04';

/// The reasons the system writes on its own. MANUAL never comes through here.
export type AutoPointSource =
  | 'MEMORIZATION'
  | 'PRESENT'
  | 'ABSENCE'
  | 'MISSED_MEMORIZATION';

export interface DayRecitation {
  memorizationType: Memorization;
  amountDone: number;
}

/// `milli` is thousandths of a point, so every rate and every half page stays
/// a whole number and no float ever reaches the ledger. Never zero: a reason
/// worth nothing has no row.
export interface DesiredPoint {
  source: AutoPointSource;
  milli: number;
}

// Per page for Quran, per hadith for Hadith — the same for both subjects.
// Revision is priced as 2 points per 10 pages, paid proportionally (5 pages
// earn 1 point). A rate change reprices a day only when its recitation is
// edited — old days are not back-filled.
const RECITATION_RATE: Record<Memorization, number> = {
  MEMORIZING: 1000, // حفظ: 1 point per page
  SMALLREVISION: 200, // جمع: 2 points per 10 pages
  BIGREVISION: 200, // مراجعة وضبط: 2 points per 10 pages
};
const PRESENT = 500;
const ABSENCE = -1000;
const MISSED_MEMORIZATION = -1000;

export function countsForPoints(date: Date): boolean {
  return date.getTime() >= new Date(POINTS_START_DATE).getTime();
}

/// Which automatic point rows one student should have for one day.
///
/// Pure, like `desiredCharges` for fines: the caller diffs this against the
/// stored rows, so every awkward case is decided — and tested — here.
export function desiredPoints(input: {
  date: Date;
  status: AttendanceStatus | null;
  justified: boolean;
  recitations: DayRecitation[];
}): DesiredPoint[] {
  const { date, status, justified, recitations } = input;
  if (!countsForPoints(date)) return [];

  const wanted: DesiredPoint[] = [];

  const recited = recitations.reduce(
    (sum, r) =>
      sum + Math.round(r.amountDone * RECITATION_RATE[r.memorizationType]),
    0,
  );
  wanted.push({ source: 'MEMORIZATION', milli: recited });

  if (status === AttendanceStatus.PRESENT) {
    wanted.push({ source: 'PRESENT', milli: PRESENT });
  }
  // An excused absence costs nothing; the excuse is only read on an absent day.
  if (status === AttendanceStatus.ABSENT && !justified) {
    wanted.push({ source: 'ABSENCE', milli: ABSENCE });
  }
  // An absent student is already losing the absence point; the missed
  // recitation follows from it rather than being a second fault.
  if (
    (status === AttendanceStatus.PRESENT || status === AttendanceStatus.LATE) &&
    recitations.length === 0
  ) {
    wanted.push({ source: 'MISSED_MEMORIZATION', milli: MISSED_MEMORIZATION });
  }

  return wanted.filter((p) => p.milli !== 0);
}

/// Thousandths to the exact decimal string Prisma stores in DECIMAL(10,3).
/// Integer arithmetic only: `(milli / 1000).toFixed(3)` would route through a
/// float.
export function milliToAmount(milli: number): string {
  const sign = milli < 0 ? '-' : '';
  const abs = Math.abs(milli);
  return `${sign}${Math.trunc(abs / 1000)}.${String(abs % 1000).padStart(3, '0')}`;
}
