import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { CreateFineDto } from './fine.dto';

// `reason` is optional on a manual entry — the statement falls back to a
// generic label — but when given it still has to fit the 300-char column.
describe('CreateFineDto', () => {
  const base = { studentId: 7, kind: 'CHARGE', amount: 40 };

  it('accepts a manual entry with no reason', async () => {
    const dto = plainToInstance(CreateFineDto, { ...base });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('accepts a manual entry with an empty reason', async () => {
    const dto = plainToInstance(CreateFineDto, { ...base, reason: '' });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('accepts a manual entry with a reason', async () => {
    const dto = plainToInstance(CreateFineDto, {
      ...base,
      reason: 'إتلاف مصحف',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });

  it('rejects a reason longer than 300 characters', async () => {
    const dto = plainToInstance(CreateFineDto, {
      ...base,
      reason: 'a'.repeat(301),
    });

    const errors = await validate(dto);

    expect(errors.some((e) => e.property === 'reason')).toBe(true);
  });
});
