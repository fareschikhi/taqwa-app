import { AttendanceStatus, Memorization, ProgressUnit } from '@prisma/client';

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
  unit: ProgressUnit;
}

/// `milli` is thousandths of a point, so every rate and every half page stays
/// a whole number and no float ever reaches the ledger. Never zero: a reason
/// worth nothing has no row.
export interface DesiredPoint {
  source: AutoPointSource;
  milli: number;
}

// Priced by the unit, not the subject: a hadith page earns what a Quran page
// earns, and a single hadith earns half of that. Revision is paid
// proportionally (5 pages earn 1 point). A rate change reprices a day only
// when its recitation is edited — old days are not back-filled.
const RECITATION_RATE: Record<ProgressUnit, Record<Memorization, number>> = {
  PAGE: {
    MEMORIZING: 1000, // حفظ: 1 point per page
    SMALLREVISION: 200, // جمع: 2 points per 10 pages
    BIGREVISION: 200, // مراجعة وضبط: 2 points per 10 pages
  },
  HADITH: {
    MEMORIZING: 500, // حفظ: 0.5 point per hadith
    SMALLREVISION: 100, // جمع: 1 point per 10 hadiths
    BIGREVISION: 100, // مراجعة وضبط: 1 point per 10 hadiths
  },
  // A mushaf page holds about 10 ayahs (6,236 over 604 pages), so 10 ayahs
  // earn what a page earns, at every type.
  AYAH: {
    MEMORIZING: 100, // حفظ: 1 point per 10 ayahs
    SMALLREVISION: 20, // جمع: 2 points per 100 ayahs
    BIGREVISION: 20, // مراجعة وضبط: 2 points per 100 ayahs
  },
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
      sum +
      Math.round(r.amountDone * RECITATION_RATE[r.unit][r.memorizationType]),
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
