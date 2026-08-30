import { AttendanceStatus } from '@prisma/client';
import { desiredCharges } from './fine-reconciliation';

const RATES = { absenceFee: 50, lateFee: 20, missedMemorizationFee: 30 };

describe('desiredCharges', () => {
  it('charges the absence fee for an absent student', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.ABSENT,
        missedMemorization: false,
        rates: RATES,
      }),
    ).toEqual([{ source: 'ABSENCE', amount: 50 }]);
  });

  it('charges the late fee for a late student', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.LATE,
        missedMemorization: false,
        rates: RATES,
      }),
    ).toEqual([{ source: 'LATE', amount: 20 }]);
  });

  it('charges nothing for a present student who memorized', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.PRESENT,
        missedMemorization: false,
        rates: RATES,
      }),
    ).toEqual([]);
  });

  it('charges the memorization fee on top of lateness', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.LATE,
        missedMemorization: true,
        rates: RATES,
      }),
    ).toEqual([
      { source: 'LATE', amount: 20 },
      { source: 'MISSED_MEMORIZATION', amount: 30 },
    ]);
  });

  // He is already paying for not being there. Charging him again for not
  // reciting while absent would be charging the same fact twice.
  it('never charges an absent student for not memorizing', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.ABSENT,
        missedMemorization: true,
        rates: RATES,
      }),
    ).toEqual([{ source: 'ABSENCE', amount: 50 }]);
  });

  it('charges nothing when the student has no halaqa', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.ABSENT,
        missedMemorization: true,
        rates: null,
      }),
    ).toEqual([]);
  });

  // A halaqa that fines absence but not lateness is a real configuration, and
  // a zero-amount row would clutter his statement saying nothing.
  it('omits a fee the halaqa has set to zero', () => {
    expect(
      desiredCharges({
        status: AttendanceStatus.LATE,
        missedMemorization: true,
        rates: { absenceFee: 50, lateFee: 0, missedMemorizationFee: 30 },
      }),
    ).toEqual([{ source: 'MISSED_MEMORIZATION', amount: 30 }]);
  });
});
