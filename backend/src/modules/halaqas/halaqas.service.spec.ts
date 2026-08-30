import { BadRequestException } from '@nestjs/common';
import { HalaqasService } from './halaqas.service';

// The service only needs to read the roles of the students being connected,
// so the mock answers that one query and records the write it would make.
const makeService = (roles: Array<{ id: number; role: string }>) => {
  const prisma = {
    student: {
      findMany: jest
        .fn()
        .mockResolvedValue(
          roles.map((r) => ({ id: r.id, user: { role: r.role } })),
        ),
    },
    halaqa: {
      findUnique: jest.fn().mockResolvedValue({ id: 1, isAdult: false }),
      create: jest.fn().mockResolvedValue({ id: 1 }),
      update: jest.fn().mockResolvedValue({ id: 1 }),
    },
  };
  return { service: new HalaqasService(prisma as any), prisma };
};

describe('HalaqasService enrolment validation', () => {
  it('refuses a child student in an adults halaqa', async () => {
    const { service } = makeService([{ id: 7, role: 'STUDENT' }]);

    await expect(
      service.create({
        name: 'حلقة الكبار',
        teacherId: 1,
        isAdult: true,
        studentIds: [7],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses an adult student in a normal halaqa', async () => {
    const { service } = makeService([{ id: 21, role: 'ADULT_STUDENT' }]);

    await expect(
      service.create({
        name: 'حلقة النور',
        teacherId: 1,
        studentIds: [21],
      } as any),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts adult students in an adults halaqa', async () => {
    const { service, prisma } = makeService([
      { id: 21, role: 'ADULT_STUDENT' },
      { id: 22, role: 'ADULT_STUDENT' },
    ]);

    await service.create({
      name: 'حلقة الكبار',
      teacherId: 1,
      isAdult: true,
      studentIds: [21, 22],
    });

    expect(prisma.halaqa.create).toHaveBeenCalled();
  });

  it('skips the check when no students are being connected', async () => {
    const { service, prisma } = makeService([]);

    await service.create({ name: 'حلقة النور', teacherId: 1 });

    expect(prisma.student.findMany).not.toHaveBeenCalled();
    expect(prisma.halaqa.create).toHaveBeenCalled();
  });
});
