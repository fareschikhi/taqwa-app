import { AttendanceStatus, Prisma } from '@prisma/client';
import { desiredCharges, HalaqaFineRates } from './fine-reconciliation';
import { isAway } from './attendance-status';

/// Brings one student's auto-charges for one day in line with what is on
/// file for that day, inside the caller's transaction — so a fine can never
/// outlive (or precede) the row it follows from.
///
/// "Did not memorize" is derived here rather than taken from the teacher: a
/// student who attended and has no recitation recorded for the day did not
/// memorize. Both writes that can change that answer call this — attendance
/// (the status moved) and memorization (a recitation was just recorded) — so
/// the charge appears at roll call and disappears with the first recitation.
///
/// Written as a reconciliation rather than an increment because attendance is
/// an upsert: the teacher re-saves the same day freely, and adding on each
/// save would charge for one absence many times over.
///
/// Returns what the attendance status itself cost (absence/late), for the
/// notification body. The memorization charge is left out on purpose: at roll
/// call it is provisional — the student has usually not recited *yet* — so
/// announcing it would tell him he was fined for something still undecided.
///
/// [lateFee] is the amount the teacher chose for this late arrival. It
/// replaces the halaqa's rate, and — unlike a rate change — it does reprice a
/// late charge already on file, because the teacher is deciding *this* day.
/// Left undefined (memorization saves, older app builds), the stored charge
/// keeps its amount.
export async function reconcileDayFines(
  tx: Prisma.TransactionClient,
  studentId: number,
  date: Date,
  status: AttendanceStatus,
  actorUserId: number | null,
  lateFee?: number,
): Promise<number> {
  const student = await tx.student.findUnique({
    where: { id: studentId },
    select: {
      userId: true,
      user: { select: { role: true } },
      halaqa: {
        select: {
          isAdult: true,
          absenceFee: true,
          lateFee: true,
          missedMemorizationFee: true,
        },
      },
    },
  });

  if (student?.user?.role !== 'ADULT_STUDENT') return 0;

  const halaqa = student.halaqa;
  const rates: HalaqaFineRates | null =
    halaqa && halaqa.isAdult
      ? {
          absenceFee: halaqa.absenceFee,
          lateFee: lateFee ?? halaqa.lateFee,
          missedMemorizationFee: halaqa.missedMemorizationFee,
        }
      : null;

  // A student who was away (absent, or excused) cannot have recited, so the
  // lookup is skipped rather than answered.
  const missedMemorization =
    !isAway(status) &&
    (await tx.memorizationProgress.count({ where: { studentId, date } })) ===
      0;

  // Kept on the row as the day's record: if the fine is later forgiven, the
  // day was still a day he did not memorize.
  await tx.attendance.updateMany({
    where: { studentId, date },
    data: { missedMemorization },
  });

  const wanted = desiredCharges({ status, missedMemorization, rates });

  const existing = await tx.fineEntry.findMany({
    where: { studentId, date, source: { not: 'MANUAL' } },
    select: { id: true, source: true, amount: true },
  });

  const wantedSources = new Set<string>(wanted.map((c) => c.source));
  const stale = existing
    .filter((row) => !wantedSources.has(row.source))
    .map((row) => row.id);
  if (stale.length > 0) {
    await tx.fineEntry.deleteMany({ where: { id: { in: stale } } });
  }

  const kept = new Map(
    existing
      .filter((row) => wantedSources.has(row.source))
      .map((r) => [r.source, r] as const),
  );

  let charged = 0;
  for (const charge of wanted) {
    // An existing charge keeps the amount it was created at. Raising a
    // halaqa's rate must not reprice a day that was already charged, and
    // re-saving an old sheet is exactly how that would happen. The one
    // exception is a late amount the teacher typed for this very day.
    const row = kept.get(charge.source);
    if (row) {
      const repriced =
        charge.source === 'LATE' &&
        lateFee !== undefined &&
        row.amount !== charge.amount;
      if (repriced) {
        await tx.fineEntry.update({
          where: { id: row.id },
          data: { amount: charge.amount },
        });
        charged += charge.amount;
      }
      continue;
    }
    await tx.fineEntry.create({
      data: {
        studentId,
        kind: 'CHARGE',
        amount: charge.amount,
        source: charge.source,
        date,
        createdById: actorUserId ?? student.userId,
      },
    });
    if (charge.source !== 'MISSED_MEMORIZATION') charged += charge.amount;
  }

  return charged;
}
