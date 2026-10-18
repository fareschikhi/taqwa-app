import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import { UpdateStudentDto } from './student.dto';
import { HADITH_BOOKS } from '../hadith-books';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body: ArgumentMetadata = {
  type: 'body',
  metatype: UpdateStudentDto,
  data: '',
};

describe('student DTO hadithBooks', () => {
  it('keeps the books an admin ticked', async () => {
    const dto = (await pipe.transform(
      { hadithBooks: [HADITH_BOOKS[0], HADITH_BOOKS[5]] },
      body,
    )) as UpdateStudentDto;

    expect(dto.hadithBooks).toEqual([HADITH_BOOKS[0], HADITH_BOOKS[5]]);
  });

  it('accepts an empty list, which turns hadith off', async () => {
    const dto = (await pipe.transform(
      { hadithBooks: [] },
      body,
    )) as UpdateStudentDto;

    expect(dto.hadithBooks).toEqual([]);
  });

  it('rejects a book that is not on the list', async () => {
    await expect(
      pipe.transform({ hadithBooks: ['صحيح البخاري'] }, body),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects the same book twice', async () => {
    await expect(
      pipe.transform({ hadithBooks: [HADITH_BOOKS[0], HADITH_BOOKS[0]] }, body),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
