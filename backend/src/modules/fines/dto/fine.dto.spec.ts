import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';
import { CreateFineDto } from './fine.dto';

// `reason` is optional on the wire only for an auto-charge, and those never
// reach this DTO — they are written straight to the database by the
// attendance reconciliation with `source` carrying the explanation instead.
// A manual entry has nothing else to say why money moved, so this is the one
// path that must refuse to accept it missing.
describe('CreateFineDto', () => {
  const base = { studentId: 7, kind: 'CHARGE', amount: 40 };

  it('rejects a manual entry with no reason', async () => {
    const dto = plainToInstance(CreateFineDto, { ...base });

    const errors = await validate(dto);

    expect(errors.some((e) => e.property === 'reason')).toBe(true);
  });

  it('rejects a manual entry with an empty reason', async () => {
    const dto = plainToInstance(CreateFineDto, { ...base, reason: '' });

    const errors = await validate(dto);

    expect(errors.some((e) => e.property === 'reason')).toBe(true);
  });

  it('accepts a manual entry with a reason', async () => {
    const dto = plainToInstance(CreateFineDto, {
      ...base,
      reason: 'إتلاف مصحف',
    });

    const errors = await validate(dto);

    expect(errors).toHaveLength(0);
  });
});
