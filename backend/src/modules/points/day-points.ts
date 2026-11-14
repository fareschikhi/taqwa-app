import { Prisma } from '@prisma/client';
import { countsForPoints, desiredPoints, milliToAmount } from './points-rules';

/// Brings one student's automatic point rows for one day in line with what is
/// on file for that day, inside the caller's transaction — so points can never
/// outlive (or precede) the attendance or recitation they follow from.
///
/// A reconciliation rather than an increment, for the same reason as fines:
/// the teacher re-saves a day freely, and adding on each save would reward one
/// recitation many times over.
///
/// Attendance rows keep the amount they were created with, so changing a rate
/// later never reprices an old day just because its sheet was re-saved. The
/// memorization row is the exception: editing a recitation has to move it.
export async function reconcileDayPoints(
  tx: Prisma.TransactionClient,
  studentId: number,
  date: Date,
): Promise<void> {
  if (!countsForPoints(date)) return;

  const student = await tx.student.findUnique({
    where: { id: studentId },
    select: { userId: true, user: { select: { role: true } } },
  });
  const role = student?.user?.role;
  if (!student || (role !== 'STUDENT' && role !== 'ADULT_STUDENT')) return;

  const attendance = await tx.attendance.findUnique({
    where: { studentId_date: { studentId, date } },
    select: { status: true, justification: { select: { id: true } } },
  });
  const recitations = await tx.memorizationProgress.findMany({
    where: { studentId, date },
    select: {
      memorizationType: true,
      amountDone: true,
      unit: true,
      outsideSession: true,
      isRepeat: true,
    },
  });

  const wanted = desiredPoints({
    date,
    status: attendance?.status ?? null,
    justified: !!attendance?.justification,
    recitations,
  });

  const userId = student.userId;
  const existing = await tx.pointEntry.findMany({
    where: { userId, date, source: { not: 'MANUAL' } },
    select: { id: true, source: true, amount: true },
  });

  const wantedBySource = new Map(wanted.map((p) => [p.source as string, p]));
  const stale = existing
    .filter((row) => !wantedBySource.has(row.source))
    .map((row) => row.id);
  if (stale.length > 0) {
    await tx.pointEntry.deleteMany({ where: { id: { in: stale } } });
  }

  const stored = new Map(existing.map((row) => [row.source as string, row]));
  for (const point of wanted) {
    const row = stored.get(point.source);
    if (!row) {
      await tx.pointEntry.create({
        data: { userId, amount: milliToAmount(point.milli), source: point.source, date },
      });
      continue;
    }
    // Compared in thousandths through Decimal arithmetic: Prisma hands back
    // Decimal('2'), and comparing that to '2.000' as text would rewrite the
    // row on every save.
    const storedMilli = new Prisma.Decimal(row.amount).mul(1000).toNumber();
    if (point.source === 'MEMORIZATION' && storedMilli !== point.milli) {
      await tx.pointEntry.update({
        where: { id: row.id },
        data: { amount: milliToAmount(point.milli) },
      });
    }
  }
}
