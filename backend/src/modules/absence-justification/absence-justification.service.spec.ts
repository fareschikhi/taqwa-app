jest.mock('../points/day-points', () => ({
  reconcileDayPoints: jest.fn().mockResolvedValue(undefined),
}));
import { JustificationReasonType } from '@prisma/client';
import { reconcileDayPoints } from '../points/day-points';
import { AbsenceJustificationService } from './absence-justification.service';

describe('AbsenceJustificationService.create keeps daily points in step', () => {
  const points = jest.mocked(reconcileDayPoints);
  beforeEach(() => points.mockClear());

  const day = new Date('2026-11-05');
  const makePrisma = (attendance: { studentId: number; date: Date } | null) => {
    const prisma: any = {
      attendance: { findUnique: jest.fn().mockResolvedValue(attendance) },
      absenceJustification: { create: jest.fn().mockResolvedValue({ id: 3 }) },
    };
    prisma.$transaction = jest.fn((cb: any) => cb(prisma));
    return prisma;
  };
  const dto = {
    studentId: 7,
    attendanceId: 40,
    managerId: 2,
    reasonType: JustificationReasonType.ILLNESS,
  };

  it('reconciles the excused day after recording the excuse', async () => {
    const prisma = makePrisma({ studentId: 7, date: day });
    const result = await new AbsenceJustificationService(prisma).create(dto);

    expect(result).toEqual({ id: 3 });
    expect(prisma.$transaction).toHaveBeenCalled();
    expect(prisma.attendance.findUnique).toHaveBeenCalledWith({
      where: { id: 40 },
      select: { studentId: true, date: true },
    });
    expect(points).toHaveBeenCalledWith(prisma, 7, day);
    expect(points.mock.invocationCallOrder[0]).toBeGreaterThan(
      prisma.absenceJustification.create.mock.invocationCallOrder[0],
    );
  });

  it('skips the reconcile when the attendance row does not exist', async () => {
    const prisma = makePrisma(null);
    await new AbsenceJustificationService(prisma).create(dto);
    expect(points).not.toHaveBeenCalled();
  });
});
