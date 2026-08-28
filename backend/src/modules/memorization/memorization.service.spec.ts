import { BadRequestException } from '@nestjs/common';
import { AttendanceStatus, Memorization } from '@prisma/client';
import { MEMORIZATION_ERROR, MemorizationService } from './memorization.service';

describe('MemorizationService.create attendance gate', () => {
  const makePrisma = (status: AttendanceStatus | null) => ({
    attendance: {
      findUnique: jest
        .fn()
        .mockResolvedValue(status === null ? null : { id: 1, status }),
    },
    memorizationProgress: {
      create: jest.fn().mockResolvedValue({ id: 10 }),
    },
  });

  const dto = {
    studentId: 7,
    surahNumber: 2,
    amountDone: 1,
    memorizationType: Memorization.MEMORIZING,
  };

  it('refuses to record memorization for a student marked absent today', async () => {
    const prisma = makePrisma(AttendanceStatus.ABSENT);
    const service = new MemorizationService(prisma as any);

    await expect(service.create(dto)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(prisma.memorizationProgress.create).not.toHaveBeenCalled();
  });

  // The app shows a dedicated "student is absent" message for this case. It has
  // only the response body to go on, since an over-large amount is a 400 too,
  // so the code has to be what distinguishes them.
  it('tags the absence rejection with STUDENT_ABSENT', async () => {
    const prisma = makePrisma(AttendanceStatus.ABSENT);
    const service = new MemorizationService(prisma as any);

    await expect(service.create(dto)).rejects.toMatchObject({
      response: { code: MEMORIZATION_ERROR.STUDENT_ABSENT },
    });
  });

  it('leaves an over-large amount untagged, so it is not reported as absence', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    const service = new MemorizationService(prisma as any);

    // Revision is counted in hizbs, of which there are only 60.
    const tooMany = {
      ...dto,
      memorizationType: Memorization.SMALLREVISION,
      amountDone: 61,
    };

    await expect(service.create(tooMany)).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.create(tooMany)).rejects.not.toMatchObject({
      response: { code: MEMORIZATION_ERROR.STUDENT_ABSENT },
    });
  });

  it('records memorization for a present student', async () => {
    const prisma = makePrisma(AttendanceStatus.PRESENT);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('records memorization for a late student', async () => {
    const prisma = makePrisma(AttendanceStatus.LATE);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });

  it('records memorization when attendance has not been taken yet', async () => {
    const prisma = makePrisma(null);
    const service = new MemorizationService(prisma as any);

    await service.create(dto);

    expect(prisma.memorizationProgress.create).toHaveBeenCalled();
  });
});
