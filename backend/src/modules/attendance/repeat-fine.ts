import { Prisma } from '@prisma/client';

/// Brings one adult student's repeat (إعادة) charge for one day in line with
/// the repeat recitations on file for that day, inside the caller's
/// transaction.
///
/// Kept apart from `reconcileDayFines` because it does not depend on roll
/// call: a repeat recorded outside the session, or before attendance is taken,
/// is still charged. The fine table holds one row per day and reason, so the
/// day's row carries `repeatFee × repeats`.
///
/// Unlike the attendance charges, the row is repriced on every change: adding
/// or deleting a repeat has to move it. A halaqa that stops charging (fee 0,
/// or no longer adult) leaves an existing charge alone. Lowering a rate must
/// not erase what was already owed, the same rule the other fines follow.
export async function reconcileRepeatFine(
  tx: Prisma.TransactionClient,
  studentId: number,
  date: Date,
  actorUserId: number | null,
): Promise<void> {
  const repeats = await tx.memorizationProgress.count({
    where: { studentId, date, isRepeat: true },
  });
  const existing = await tx.fineEntry.findFirst({
    where: { studentId, date, source: 'REPEAT' },
    select: { id: true, amount: true },
  });

  // Nothing left to charge for, whatever the halaqa's rate is now.
  if (repeats === 0) {
    if (existing) await tx.fineEntry.delete({ where: { id: existing.id } });
    return;
  }

  const student = await tx.student.findUnique({
    where: { id: studentId },
    select: {
      userId: true,
      user: { select: { role: true } },
      halaqa: { select: { isAdult: true, repeatFee: true } },
    },
  });
  const fee =
    student?.user?.role === 'ADULT_STUDENT' && student.halaqa?.isAdult
      ? student.halaqa.repeatFee
      : 0;
  if (fee <= 0) return;

  const amount = fee * repeats;
  if (existing) {
    if (existing.amount !== amount) {
      await tx.fineEntry.update({
        where: { id: existing.id },
        data: { amount },
      });
    }
    return;
  }
  await tx.fineEntry.create({
    data: {
      studentId,
      kind: 'CHARGE',
      amount,
      source: 'REPEAT',
      date,
      createdById: actorUserId ?? student!.userId,
    },
  });
}
