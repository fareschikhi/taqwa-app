import {
  ArgumentMetadata,
  BadRequestException,
  ValidationPipe,
} from '@nestjs/common';
import { CreateParentDto, UpdateParentDto } from '../../modules/parents/dto/parent.dto';
import { LoginDto } from '../../modules/auth/dto/login.dto';
import { normalizePhone } from './account-fields';

// Same configuration main.ts installs globally, so these exercise the real
// request path rather than class-validator in isolation.
const pipe = new ValidationPipe({ whitelist: true, transform: true });

const body = (metatype: unknown): ArgumentMetadata => ({
  type: 'body',
  metatype: metatype as ArgumentMetadata['metatype'],
  data: '',
});

const valid = { fullName: 'Ahmed Boudiaf', password: 'secret1' };

const errorsFor = async (dto: unknown, input: object): Promise<string[]> => {
  try {
    await pipe.transform(input, body(dto));
    return [];
  } catch (e) {
    expect(e).toBeInstanceOf(BadRequestException);
    const response = (e as BadRequestException).getResponse() as { message: string[] };
    return response.message;
  }
};

describe('normalizePhone', () => {
  it.each([
    ['0551234567', '0551234567'],
    ['05 51 23 45 67', '0551234567'],
    ['055-123-4567', '0551234567'],
    ['+213 551 23 45 67', '0551234567'],
    ['00213661234567', '0661234567'],
    ['1001', '1001'],
  ])('%s -> %s', (input, expected) => {
    expect(normalizePhone(input)).toBe(expected);
  });
});

describe('account fields on create', () => {
  it('accepts a minimal valid account', async () => {
    expect(await errorsFor(CreateParentDto, valid)).toEqual([]);
  });

  it('stores the phone in its normalized form', async () => {
    const dto = (await pipe.transform(
      { ...valid, phone: '+213 771 23 45 67' },
      body(CreateParentDto),
    )) as CreateParentDto;
    expect(dto.phone).toBe('0771234567');
  });

  it.each(['0451234567', '055123456', '05512345678', '1001', 'abc'])(
    'rejects the phone %s',
    async (phone) => {
      expect(await errorsFor(CreateParentDto, { ...valid, phone })).toEqual([
        'رقم الهاتف غير صالح: 10 أرقام تبدأ بـ 05 أو 06 أو 07',
      ]);
    },
  );

  it.each(['not-an-email', 'a@b', 'x@y .com'])('rejects the email %s', async (email) => {
    expect(await errorsFor(CreateParentDto, { ...valid, email })).toEqual([
      'البريد الإلكتروني غير صالح',
    ]);
  });

  it('accepts blank phone and email, which the service stores as none', async () => {
    expect(await errorsFor(CreateParentDto, { ...valid, phone: '', email: '' })).toEqual([]);
  });

  it('rejects a whitespace-only name', async () => {
    expect(await errorsFor(CreateParentDto, { ...valid, fullName: '   ' })).toEqual([
      'الاسم مطلوب',
    ]);
  });

  it('rejects a short password', async () => {
    expect(await errorsFor(CreateParentDto, { ...valid, password: '12345' })).toEqual([
      'كلمة المرور يجب أن تكون 6 أحرف على الأقل',
    ]);
  });
});

describe('account fields on update', () => {
  it('leaves omitted fields alone', async () => {
    expect(await errorsFor(UpdateParentDto, {})).toEqual([]);
  });

  it('still checks a phone that is sent', async () => {
    expect(await errorsFor(UpdateParentDto, { phone: '123' })).toHaveLength(1);
  });
});

describe('LoginDto', () => {
  it('normalizes the phone but does not enforce the new format', async () => {
    const intl = (await pipe.transform(
      { phone: '+213 551 23 45 67', password: 'secret1' },
      body(LoginDto),
    )) as LoginDto;
    expect(intl.phone).toBe('0551234567');

    // Accounts created before the rule existed must still sign in.
    expect(await errorsFor(LoginDto, { phone: '1001', password: 'secret1' })).toEqual([]);
  });
});
