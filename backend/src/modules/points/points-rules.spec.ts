import { AttendanceStatus, Memorization } from '@prisma/client';
import {
  DayRecitation,
  DesiredPoint,
  POINTS_START_DATE,
  desiredPoints,
  milliToAmount,
} from './points-rules';

// Dates are counted from POINTS_START_DATE, never written out, so moving the
// start date to release day never breaks these tests.
const fromStart = (days: number) =>
  new Date(new Date(POINTS_START_DATE).getTime() + days * 86_400_000);
const D = fromStart(3);
const r = (memorizationType: Memorization, amountDone: number): DayRecitation => ({
  memorizationType,
  amountDone,
});
const sorted = (points: DesiredPoint[]) =>
  [...points].sort((a, b) => a.source.localeCompare(b.source));
const day = (
  status: AttendanceStatus | null,
  recitations: DayRecitation[] = [],
  justified = false,
  date = D,
) => sorted(desiredPoints({ date, status, justified, recitations }));

describe('desiredPoints', () => {
  it('gives nothing before the start date', () => {
    expect(
      day(AttendanceStatus.PRESENT, [], false, fromStart(-1)),
    ).toEqual([]);
  });

  it('counts the start date itself', () => {
    expect(
      day(
        AttendanceStatus.PRESENT,
        [r(Memorization.MEMORIZING, 1)],
        false,
        new Date(POINTS_START_DATE),
      ),
    ).toEqual([
      { source: 'MEMORIZATION', milli: 1000 },
      { source: 'PRESENT', milli: 500 },
    ]);
  });

  it('gives 1 per page of حفظ plus the attendance half point', () => {
    expect(day(AttendanceStatus.PRESENT, [r(Memorization.MEMORIZING, 2)])).toEqual([
      { source: 'MEMORIZATION', milli: 2000 },
      { source: 'PRESENT', milli: 500 },
    ]);
  });

  it('values half a page of مراجعة وضبط at 0.1', () => {
    expect(day(null, [r(Memorization.BIGREVISION, 0.5)])).toEqual([
      { source: 'MEMORIZATION', milli: 100 },
    ]);
  });

  it('gives 2 points for 10 pages of جمع or of مراجعة', () => {
    expect(day(null, [r(Memorization.SMALLREVISION, 10)])).toEqual([
      { source: 'MEMORIZATION', milli: 2000 },
    ]);
    expect(day(null, [r(Memorization.BIGREVISION, 10)])).toEqual([
      { source: 'MEMORIZATION', milli: 2000 },
    ]);
  });

  it('counts a partial ten proportionally', () => {
    expect(day(null, [r(Memorization.SMALLREVISION, 5)])).toEqual([
      { source: 'MEMORIZATION', milli: 1000 },
    ]);
  });

  it('sums every recitation of the day', () => {
    expect(
      day(null, [
        r(Memorization.MEMORIZING, 1),
        r(Memorization.SMALLREVISION, 1),
        r(Memorization.BIGREVISION, 1.5),
      ]),
    ).toEqual([{ source: 'MEMORIZATION', milli: 1500 }]);
  });

  it('takes a point from a present student who recited nothing', () => {
    expect(day(AttendanceStatus.PRESENT)).toEqual([
      { source: 'MISSED_MEMORIZATION', milli: -1000 },
      { source: 'PRESENT', milli: 500 },
    ]);
  });

  it('gives a late student nothing for attending', () => {
    expect(day(AttendanceStatus.LATE)).toEqual([
      { source: 'MISSED_MEMORIZATION', milli: -1000 },
    ]);
    expect(day(AttendanceStatus.LATE, [r(Memorization.MEMORIZING, 1)])).toEqual([
      { source: 'MEMORIZATION', milli: 1000 },
    ]);
  });

  it('charges an absence once, not again for the missed recitation', () => {
    expect(day(AttendanceStatus.ABSENT)).toEqual([
      { source: 'ABSENCE', milli: -1000 },
    ]);
  });

  it('forgives a justified absence', () => {
    expect(day(AttendanceStatus.ABSENT, [], true)).toEqual([]);
  });

  it('ignores a justification on a day the student attended', () => {
    expect(day(AttendanceStatus.PRESENT, [], true)).toEqual([
      { source: 'MISSED_MEMORIZATION', milli: -1000 },
      { source: 'PRESENT', milli: 500 },
    ]);
  });

  it('counts recitations recorded before roll call', () => {
    expect(day(null, [r(Memorization.MEMORIZING, 1)])).toEqual([
      { source: 'MEMORIZATION', milli: 1000 },
    ]);
    expect(day(null)).toEqual([]);
  });
});

describe('milliToAmount', () => {
  it('writes thousandths as a three-place decimal', () => {
    expect(milliToAmount(125)).toBe('0.125');
    expect(milliToAmount(-1000)).toBe('-1.000');
    expect(milliToAmount(2500)).toBe('2.500');
    expect(milliToAmount(-125)).toBe('-0.125');
  });
});
