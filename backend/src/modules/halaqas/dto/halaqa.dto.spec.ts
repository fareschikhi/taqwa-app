import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import {
  CreateHalaqaDto,
  HALAQA_LEVELS,
  UpdateHalaqaDto,
} from './halaqa.dto';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body = (metatype: unknown): ArgumentMetadata => ({
  type: 'body',
  metatype: metatype as ArgumentMetadata['metatype'],
  data: '',
});

describe('halaqa DTOs', () => {
  it('accepts each of the four categories on create', async () => {
    for (const level of HALAQA_LEVELS) {
      const dto = (await pipe.transform(
        { name: 'حلقة النور', teacherId: 1, level },
        body(CreateHalaqaDto),
      )) as CreateHalaqaDto;

      expect(dto.level).toBe(level);
    }
  });

  it('rejects a create with no category', async () => {
    await expect(
      pipe.transform({ name: 'حلقة النور', teacherId: 1 }, body(CreateHalaqaDto)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects free text that is not one of the categories', async () => {
    await expect(
      pipe.transform(
        { name: 'حلقة النور', teacherId: 1, level: 'مبتدئ' },
        body(CreateHalaqaDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('lets an update leave the category untouched', async () => {
    const dto = (await pipe.transform(
      { name: 'حلقة النور' },
      body(UpdateHalaqaDto),
    )) as UpdateHalaqaDto;

    expect(dto.level).toBeUndefined();
  });

  it('rejects clearing the category on update', async () => {
    await expect(
      pipe.transform({ level: null }, body(UpdateHalaqaDto)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects an unknown category on update', async () => {
    await expect(
      pipe.transform({ level: 'متقدم' }, body(UpdateHalaqaDto)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('drops a description an outdated client still sends', async () => {
    const dto = (await pipe.transform(
      { name: 'حلقة النور', teacherId: 1, level: 'ثانوي', description: 'وصف' },
      body(CreateHalaqaDto),
    )) as CreateHalaqaDto;

    expect('description' in dto).toBe(false);
  });

  it('drops an isStudentsChanged flag instead of forwarding it to Prisma', async () => {
    const dto = (await pipe.transform(
      { name: 'حلقة النور', isStudentsChanged: true },
      body(UpdateHalaqaDto),
    )) as UpdateHalaqaDto;

    // update() spreads the whole DTO into prisma.halaqa.update({ data }), so
    // any key that survives here and has no matching column throws.
    expect('isStudentsChanged' in dto).toBe(false);
  });

  it('keeps the fine rates an admin set on an adults halaqa', async () => {
    const dto = (await pipe.transform(
      {
        name: 'حلقة الكبار',
        teacherId: 1,
        level: 'جامعي (كبار)',
        isAdult: true,
        absenceFee: 50,
        lateFee: 20,
        missedMemorizationFee: 30,
      },
      body(CreateHalaqaDto),
    )) as CreateHalaqaDto;

    expect(dto.absenceFee).toBe(50);
    expect(dto.missedMemorizationFee).toBe(30);
  });

  it('rejects a negative fine rate', async () => {
    await expect(
      pipe.transform(
        { name: 'حلقة الكبار', teacherId: 1, isAdult: true, absenceFee: -5 },
        body(CreateHalaqaDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});
