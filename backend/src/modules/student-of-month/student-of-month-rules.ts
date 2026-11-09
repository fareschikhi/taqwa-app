import { POINTS_START_DATE } from '../points/points-rules';

/// Algeria keeps UTC+1 all year (no daylight saving), so "which month is it"
/// is a fixed shift rather than a timezone lookup. Without it, the first hour
/// of the 1st would still count as last month on the server.
const ALGIERS_OFFSET_MS = 60 * 60 * 1000;

/// Every 100 of fines in the month costs one point. 350 → 3, 99 → 0.
export const FINE_PER_POINT = 100;

/// A month as "YYYY-MM", the key stored on StudentOfMonth.
export type MonthKey = string;

export interface MonthWindow {
  month: MonthKey;
  /// UTC midnight of the 1st: the bound for `date` columns, which hold UTC days.
  dayFrom: Date;
  dayTo: Date;
  /// The same month in Algiers wall time: the bound for `createdAt`, which is
  /// when a manual entry (no `date`) was really made.
  instantFrom: Date;
  instantTo: Date;
}

const monthKey = (year: number, monthIndex: number): MonthKey =>
  `${year}-${String(monthIndex + 1).padStart(2, '0')}`;

export function windowOf(year: number, monthIndex: number): MonthWindow {
  const dayFrom = new Date(Date.UTC(year, monthIndex, 1));
  const dayTo = new Date(Date.UTC(year, monthIndex + 1, 1));
  return {
    month: monthKey(dayFrom.getUTCFullYear(), dayFrom.getUTCMonth()),
    dayFrom,
    dayTo,
    instantFrom: new Date(dayFrom.getTime() - ALGIERS_OFFSET_MS),
    instantTo: new Date(dayTo.getTime() - ALGIERS_OFFSET_MS),
  };
}

/// The month being judged right now: the one that just ended. From the 1st of
/// December (Algiers time) until the end of December, that is November.
///
/// Null while that month is entirely before points existed — there is nothing
/// to rank yet, so no teacher is asked to pick.
export function judgedMonth(now: Date): MonthWindow | null {
  const local = new Date(now.getTime() + ALGIERS_OFFSET_MS);
  const window = windowOf(local.getUTCFullYear(), local.getUTCMonth() - 1);
  if (window.dayTo.getTime() <= new Date(POINTS_START_DATE).getTime()) {
    return null;
  }
  return window;
}

export interface StudentMonthFigures {
  studentId: number;
  /// Points gathered in the month, in thousandths (the ledger's precision).
  pointsMilli: number;
  /// Fines charged minus fines reduced in the month, in the halaqa currency.
  netFines: number;
}

export interface RankedCandidate {
  studentId: number;
  pointsMilli: number;
  finesPenalty: number;
  scoreMilli: number;
  isTop: boolean;
}

/// The points one student loses to the month's fines. A month where more was
/// forgiven than charged costs nothing; it never turns into a bonus.
export function finesPenalty(netFines: number): number {
  return netFines > 0 ? Math.floor(netFines / FINE_PER_POINT) : 0;
}

/// Ranks a halaqa for one month: what each student gathered in that month,
/// minus a point per 100 of fines — never the running total, so a student
/// with a big balance but a quiet month does not win by default.
///
/// Every student with the highest score is marked top: ties are the teacher's
/// to break. Sorted best first, then by id so the order is stable.
export function rankCandidates(rows: StudentMonthFigures[]): RankedCandidate[] {
  const ranked = rows.map((r) => {
    const penalty = finesPenalty(r.netFines);
    return {
      studentId: r.studentId,
      pointsMilli: r.pointsMilli,
      finesPenalty: penalty,
      scoreMilli: r.pointsMilli - penalty * 1000,
      isTop: false,
    };
  });
  if (ranked.length === 0) return ranked;

  const best = Math.max(...ranked.map((r) => r.scoreMilli));
  for (const r of ranked) r.isTop = r.scoreMilli === best;

  return ranked.sort(
    (a, b) => b.scoreMilli - a.scoreMilli || a.studentId - b.studentId,
  );
}
