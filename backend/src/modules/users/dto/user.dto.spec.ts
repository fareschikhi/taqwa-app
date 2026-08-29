import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import { UpdateMeDto } from './user.dto';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body = (metatype: unknown): ArgumentMetadata => ({
  type: 'body',
  metatype: metatype as ArgumentMetadata['metatype'],
  data: '',
});

describe('UpdateMeDto', () => {
  it('strips fields a user must not set on themselves', async () => {
    const dto = (await pipe.transform(
      {
        fullName: 'Ahmed Boudiaf',
        role: 'ADMIN',
        isActive: false,
        password: 'hunter2',
      },
      body(UpdateMeDto),
    )) as Record<string, unknown>;

    expect(dto).toEqual({ fullName: 'Ahmed Boudiaf' });
  });

  it('accepts an empty email, which clears it', async () => {
    // The service turns '' into null; @IsEmail alone would reject it first and
    // leave that branch unreachable.
    const dto = (await pipe.transform(
      { email: '' },
      body(UpdateMeDto),
    )) as UpdateMeDto;

    expect(dto.email).toBe('');
  });

  it('still rejects a malformed email', async () => {
    await expect(
      pipe.transform({ email: 'not-an-email' }, body(UpdateMeDto)),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('accepts a well-formed email', async () => {
    const dto = (await pipe.transform(
      { email: 'ahmed@taqwa.test' },
      body(UpdateMeDto),
    )) as UpdateMeDto;

    expect(dto.email).toBe('ahmed@taqwa.test');
  });
});
