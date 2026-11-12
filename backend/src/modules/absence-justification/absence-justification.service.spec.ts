jest.mock('../points/day-points', () => ({
  reconcileDayPoints: jest.fn().mockResolvedValue(undefined),
}));
import { ForbiddenException, NotFoundException } from '@nestjs/common';
import { JustificationReasonType, Role } from '@prisma/client';
import { reconcileDayPoints } from '../points/day-points';
import { AbsenceJustificationController } from './absence-justification.controller';
import { AbsenceJustificationService } from './absence-justification.service';

describe('AbsenceJustificationService lists carry the student halaqa', () => {
  const halaqa = { select: { id: true, name: true } };

  it('includes the halaqa on justified rows', async () => {
    const prisma: any = {
      absenceJustification: { findMany: jest.fn().mockResolvedValue([]) },
    };
    await new AbsenceJustificationService(prisma).findAll(2);

    const args = prisma.absenceJustification.findMany.mock.calls[0][0];
    expect(args.where).toEqual({ managerId: 2 });
    expect(args.include.student.include.halaqa).toEqual(halaqa);
  });

  it('includes the halaqa on rows still waiting for an excuse', async () => {
    const prisma: any = {
      manager: {
        findUnique: jest.fn().mockResolvedValue({
          canAccessUnassigned: false,
          halaqas: [{ halaqaId: 4 }],
        }),
      },
      attendance: { findMany: jest.fn().mockResolvedValue([]) },
    };
    await new AbsenceJustificationService(prisma).findUnjustified(2);

    const args = prisma.attendance.findMany.mock.calls[0][0];
    expect(args.where.student).toEqual({ OR: [{ halaqaId: { in: [4] } }] });
    expect(args.include.student.include.halaqa).toEqual(halaqa);
  });

  it('lists every halaqa when no manager is given (admin view)', async () => {
    const prisma: any = {
      manager: { findUnique: jest.fn() },
      attendance: { findMany: jest.fn().mockResolvedValue([]) },
    };
    await new AbsenceJustificationService(prisma).findUnjustified();

    const args = prisma.attendance.findMany.mock.calls[0][0];
    expect(prisma.manager.findUnique).not.toHaveBeenCalled();
    expect(args.where.student).toBeUndefined();
    expect(args.include.student.include.halaqa).toEqual(halaqa);
  });
});

describe('AbsenceJustificationController pins a manager to their own id', () => {
  const service: any = {
    findAll: jest.fn(),
    findUnjustified: jest.fn(),
    findOne: jest.fn(),
    create: jest.fn(),
    update: jest.fn(),
  };
  const controller = new AbsenceJustificationController(service);
  beforeEach(() => Object.values(service).forEach((f: any) => f.mockClear()));

  const admin = { role: Role.ADMIN, manager: null };
  const manager = { role: Role.MANAGER, manager: { id: 2 } };
  const dto = {
    studentId: 7,
    attendanceId: 40,
    managerId: 9,
    reasonType: JustificationReasonType.ILLNESS,
  };

  it('ignores another manager id a manager sends on the lists', () => {
    controller.findAll(manager, '9');
    controller.findUnjustified(manager, 9);
    controller.findAll(manager);
    controller.findUnjustified(manager);

    expect(service.findAll.mock.calls).toEqual([
      [2, undefined],
      [2, undefined],
    ]);
    expect(service.findUnjustified.mock.calls).toEqual([[2], [2]]);
  });

  it('lets an admin pick any manager, or none for every halaqa', () => {
    controller.findAll(admin, '9', '7');
    controller.findUnjustified(admin, 9);
    controller.findUnjustified(admin);

    expect(service.findAll).toHaveBeenCalledWith(9, 7);
    expect(service.findUnjustified.mock.calls).toEqual([[9], [undefined]]);
  });

  it('scopes reads, writes and edits to the manager', () => {
    controller.findOne(manager, 5);
    controller.create(manager, dto);
    controller.update(manager, 5, { notes: 'x' });

    expect(service.findOne).toHaveBeenCalledWith(5, 2);
    // The body named manager 9; the excuse is filed under the signed-in one.
    expect(service.create).toHaveBeenCalledWith({ ...dto, managerId: 2 }, 2);
    expect(service.update).toHaveBeenCalledWith(5, { notes: 'x' }, 2);
  });

  it('leaves the admin unscoped', () => {
    controller.findOne(admin, 5);
    controller.create(admin, dto);
    controller.update(admin, 5, {});

    expect(service.findOne).toHaveBeenCalledWith(5, undefined);
    expect(service.create).toHaveBeenCalledWith(dto, undefined);
    expect(service.update).toHaveBeenCalledWith(5, {}, undefined);
  });

  it('refuses a manager account with no manager row', () => {
    expect(() =>
      controller.findUnjustified({ role: Role.MANAGER, manager: null }),
    ).toThrow(ForbiddenException);
    expect(service.findUnjustified).not.toHaveBeenCalled();
  });
});

describe('AbsenceJustificationService ownership checks', () => {
  const row = { id: 5, managerId: 2 };

  it("hides another manager's excuse from findOne and update", async () => {
    const prisma: any = {
      absenceJustification: {
        findUnique: jest.fn().mockResolvedValue(row),
        update: jest.fn(),
      },
    };
    const service = new AbsenceJustificationService(prisma);

    await expect(service.findOne(5, 3)).rejects.toThrow(NotFoundException);
    await expect(service.update(5, {}, 3)).rejects.toThrow(NotFoundException);
    expect(prisma.absenceJustification.update).not.toHaveBeenCalled();
    await expect(service.findOne(5, 2)).resolves.toBe(row);
  });

  it('refuses to excuse an absence outside the manager halaqas', async () => {
    const prisma: any = {
      manager: {
        findUnique: jest.fn().mockResolvedValue({
          canAccessUnassigned: false,
          halaqas: [{ halaqaId: 4 }],
        }),
      },
      attendance: { findFirst: jest.fn().mockResolvedValue(null) },
      $transaction: jest.fn(),
    };
    const dto = {
      studentId: 7,
      attendanceId: 40,
      managerId: 2,
      reasonType: JustificationReasonType.ILLNESS,
    };

    await expect(
      new AbsenceJustificationService(prisma).create(dto, 2),
    ).rejects.toThrow(NotFoundException);
    expect(prisma.attendance.findFirst).toHaveBeenCalledWith({
      where: { id: 40, student: { OR: [{ halaqaId: { in: [4] } }] } },
      select: { id: true },
    });
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });
});

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

  it('files the excuse under the absent student, not the body studentId', async () => {
    const prisma = makePrisma({ studentId: 8, date: day });
    await new AbsenceJustificationService(prisma).create(dto);

    const args = prisma.absenceJustification.create.mock.calls[0][0];
    expect(args.data.studentId).toBe(8);
  });

  it('skips the reconcile when the attendance row does not exist', async () => {
    const prisma = makePrisma(null);
    await new AbsenceJustificationService(prisma).create(dto);
    expect(points).not.toHaveBeenCalled();
  });
});
