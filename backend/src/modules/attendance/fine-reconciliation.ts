import { AttendanceStatus } from '@prisma/client';

/// The reasons the system charges on its own. A manual entry uses the MANUAL
/// source instead and never comes through here.
export type AutoFineSource = 'ABSENCE' | 'LATE' | 'MISSED_MEMORIZATION';

export interface HalaqaFineRates {
  absenceFee: number;
  lateFee: number;
  missedMemorizationFee: number;
}

export interface DesiredCharge {
  source: AutoFineSource;
  amount: number;
}

/// Which auto-charges should exist for one student on one day.
///
/// Deliberately pure and total: the caller compares this against the rows
/// already stored and writes the difference, so every awkward case — a
/// corrected status, a re-saved sheet, a halaqa with no rates — is decided
/// here and testable without a database.
export function desiredCharges(input: {
  status: AttendanceStatus;
  missedMemorization: boolean;
  rates: HalaqaFineRates | null;
}): DesiredCharge[] {
  const { status, missedMemorization, rates } = input;
  // No halaqa, or a halaqa that charges nothing, is an ordinary case rather
  // than an error: attendance still saves, it just costs nothing.
  if (!rates) return [];

  const charges: DesiredCharge[] = [];

  if (status === AttendanceStatus.ABSENT) {
    charges.push({ source: 'ABSENCE', amount: rates.absenceFee });
  } else if (status === AttendanceStatus.LATE) {
    charges.push({ source: 'LATE', amount: rates.lateFee });
  }

  // An absent student is already paying for the absence; the missed recitation
  // follows from it rather than being a second thing he did wrong.
  if (missedMemorization && status !== AttendanceStatus.ABSENT) {
    charges.push({
      source: 'MISSED_MEMORIZATION',
      amount: rates.missedMemorizationFee,
    });
  }

  return charges.filter((c) => c.amount > 0);
}
