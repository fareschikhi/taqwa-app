import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import { CreateGroupMemorizationDto, MAX_GROUP_SIZE } from './memorization.dto';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body: ArgumentMetadata = {
  type: 'body',
  metatype: CreateGroupMemorizationDto,
  data: '',
};

const entry = {
  surahNumber: 1,
  unit: 'AYAH',
  ayahFrom: 1,
  ayahTo: 3,
  amountDone: 3,
};

describe('CreateGroupMemorizationDto', () => {
  it('accepts a list of students and one shared entry', async () => {
    const dto = (await pipe.transform(
      { studentIds: [7, 8], entry },
      body,
    )) as CreateGroupMemorizationDto;

    expect(dto.studentIds).toEqual([7, 8]);
    expect(dto.entry.amountDone).toBe(3);
  });

  it('refuses an empty or repeated student list', async () => {
    for (const studentIds of [[], [7, 7]]) {
      await expect(
        pipe.transform({ studentIds, entry }, body),
      ).rejects.toBeInstanceOf(BadRequestException);
    }
  });

  it('refuses a list longer than the group cap', async () => {
    const studentIds = Array.from(
      { length: MAX_GROUP_SIZE + 1 },
      (_, i) => i + 1,
    );
    await expect(
      pipe.transform({ studentIds, entry }, body),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  // The entry is nested, so without @ValidateNested a bad amount would slip
  // past the pipe and only the service would catch it.
  it('validates the nested entry', async () => {
    await expect(
      pipe.transform({ studentIds: [7], entry: { amountDone: 0 } }, body),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  // A group shares a Quran recitation only; per-student fields are stripped.
  it('strips a studentId or hadith reference from the shared entry', async () => {
    const dto = (await pipe.transform(
      {
        studentIds: [7],
        entry: { ...entry, studentId: 99, hadithReference: 'x' },
      },
      body,
    )) as CreateGroupMemorizationDto;

    expect(dto.entry).not.toHaveProperty('studentId');
    expect(dto.entry).not.toHaveProperty('hadithReference');
  });
});
