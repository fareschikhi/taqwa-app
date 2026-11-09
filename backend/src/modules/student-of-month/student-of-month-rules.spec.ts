import {
  finesPenalty,
  judgedMonth,
  rankCandidates,
  windowOf,
} from './student-of-month-rules';

describe('finesPenalty', () => {
  it('takes one point per full 100', () => {
    expect(finesPenalty(350)).toBe(3);
    expect(finesPenalty(100)).toBe(1);
    expect(finesPenalty(99)).toBe(0);
  });

  it('never rewards a month where more was forgiven than charged', () => {
    expect(finesPenalty(-500)).toBe(0);
  });
});

describe('rankCandidates', () => {
  it('ranks by the month, not the running total', () => {
    // The request's own example: 20 points with 350 of fines is 17, and beats
    // a student who gathered 5 this month whatever his total.
    const ranked = rankCandidates([
      { studentId: 2, pointsMilli: 5000, netFines: 0 },
      { studentId: 1, pointsMilli: 20000, netFines: 350 },
    ]);
    expect(ranked[0]).toMatchObject({
      studentId: 1,
      finesPenalty: 3,
      scoreMilli: 17000,
      isTop: true,
    });
    expect(ranked[1]).toMatchObject({ studentId: 2, isTop: false });
  });

  it('marks every tied student as top', () => {
    const ranked = rankCandidates([
      { studentId: 3, pointsMilli: 8000, netFines: 0 },
      { studentId: 1, pointsMilli: 9000, netFines: 100 },
      { studentId: 2, pointsMilli: 2000, netFines: 0 },
    ]);
    expect(ranked.filter((r) => r.isTop).map((r) => r.studentId)).toEqual([
      1, 3,
    ]);
  });

  it('still has a top when everyone is negative', () => {
    const ranked = rankCandidates([
      { studentId: 1, pointsMilli: -3000, netFines: 0 },
      { studentId: 2, pointsMilli: -1000, netFines: 0 },
    ]);
    expect(ranked[0]).toMatchObject({ studentId: 2, isTop: true });
  });

  it('returns nothing for an empty halaqa', () => {
    expect(rankCandidates([])).toEqual([]);
  });
});

describe('judgedMonth', () => {
  it('judges the month that just ended', () => {
    expect(judgedMonth(new Date('2026-12-15T10:00:00Z'))?.month).toBe(
      '2026-11',
    );
  });

  it('switches at midnight Algiers time, an hour before UTC', () => {
    // 23:30 UTC on 30 Nov is 00:30 on 1 Dec in Algiers.
    expect(judgedMonth(new Date('2026-11-30T23:30:00Z'))?.month).toBe(
      '2026-11',
    );
    expect(judgedMonth(new Date('2026-11-30T22:30:00Z'))).toBeNull();
  });

  it('crosses the year', () => {
    expect(judgedMonth(new Date('2027-01-05T10:00:00Z'))?.month).toBe(
      '2026-12',
    );
  });

  it('asks for nothing before points existed', () => {
    // November is "now", so October is judged — and October had no points.
    expect(judgedMonth(new Date('2026-11-09T10:00:00Z'))).toBeNull();
  });
});

describe('windowOf', () => {
  it('bounds manual entries by Algiers wall time', () => {
    const w = windowOf(2026, 10);
    expect(w.dayFrom.toISOString()).toBe('2026-11-01T00:00:00.000Z');
    expect(w.dayTo.toISOString()).toBe('2026-12-01T00:00:00.000Z');
    expect(w.instantFrom.toISOString()).toBe('2026-10-31T23:00:00.000Z');
    expect(w.instantTo.toISOString()).toBe('2026-11-30T23:00:00.000Z');
  });
});
