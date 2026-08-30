import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import { CreateHalaqaDto, UpdateHalaqaDto } from './halaqa.dto';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body = (metatype: unknown): ArgumentMetadata => ({
  type: 'body',
  metatype: metatype as ArgumentMetadata['metatype'],
  data: '',
});

describe('halaqa DTOs', () => {
  it('keeps the level an admin picked on create', async () => {
    const dto = (await pipe.transform(
      { name: 'حلقة النور', teacherId: 1, level: 'مبتدئ' },
      body(CreateHalaqaDto),
    )) as CreateHalaqaDto;

    expect(dto.level).toBe('مبتدئ');
  });

  it('rejects a level longer than the column holds', async () => {
    await expect(
      pipe.transform(
        { name: 'حلقة النور', teacherId: 1, level: 'م'.repeat(101) },
        body(CreateHalaqaDto),
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts a null level on update so an admin can clear it', async () => {
    const dto = (await pipe.transform(
      { level: null },
      body(UpdateHalaqaDto),
    )) as UpdateHalaqaDto;

    expect(dto.level).toBeNull();
  });

  it('drops a description an outdated client still sends', async () => {
    const dto = (await pipe.transform(
      { name: 'حلقة النور', teacherId: 1, description: 'وصف' },
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
