import { AttendanceStatus } from '@prisma/client';

/// Whether the student was not in the halaqa that day: absent, or away with
/// an excuse (عذر). Either way there was nothing to recite, so recitation is
/// refused and "did not memorize" is never charged.
///
/// Only ABSENT counts *against* the student — see [countsForRate].
export function isAway(status: AttendanceStatus | null | undefined): boolean {
  return status === AttendanceStatus.ABSENT || status === AttendanceStatus.EXCUSED;
}

/// The statuses a rate is computed over. EXCUSED is left out entirely: it is
/// neither a day attended nor a day missed, so it must move neither side.
export const RATED_STATUSES: AttendanceStatus[] = [
  AttendanceStatus.PRESENT,
  AttendanceStatus.LATE,
  AttendanceStatus.ABSENT,
];
