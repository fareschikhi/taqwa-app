import { applyDecorators } from '@nestjs/common';
import { Transform } from 'class-transformer';
import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

/** An Algerian mobile in its stored form: 05/06/07 followed by 8 digits. */
export const ALGERIAN_MOBILE = /^0[567]\d{8}$/;

/**
 * Strips spacing/punctuation and folds +213/00213 into the local 0 prefix, so
 * "+213 551 23 45 67" and "0551234567" are stored — and matched at login — as
 * the same string. Anything else is left for the format check to judge.
 */
export function normalizePhone(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const compact = value.replace(/[\s\-.()]/g, '');
  const international = /^(?:\+|00)213(\d{9})$/.exec(compact);
  return international ? `0${international[1]}` : compact;
}

const trim = () =>
  Transform(({ value }) => (typeof value === 'string' ? value.trim() : value));

/** Trims first, so a whitespace-only name fails IsNotEmpty rather than passing it. */
export const IsFullName = () =>
  applyDecorators(
    trim(),
    IsString(),
    IsNotEmpty({ message: 'الاسم مطلوب' }),
    MaxLength(100, { message: 'الاسم طويل جداً' }),
  );

export const IsPassword = () =>
  applyDecorators(
    IsString(),
    MinLength(6, { message: 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' }),
  );

// For the two below, '' is let through on purpose: it is how the app clears a
// field on edit (and sends a blank one on create), and every service already
// turns it into null/undefined.

export const IsOptionalPhone = () =>
  applyDecorators(
    IsOptional(),
    Transform(({ value }) => normalizePhone(value)),
    ValidateIf((_, value) => value !== ''),
    IsString(),
    Matches(ALGERIAN_MOBILE, {
      message: 'رقم الهاتف غير صالح: 10 أرقام تبدأ بـ 05 أو 06 أو 07',
    }),
  );

export const IsOptionalEmail = () =>
  applyDecorators(
    IsOptional(),
    trim(),
    ValidateIf((_, value) => value !== ''),
    IsEmail({}, { message: 'البريد الإلكتروني غير صالح' }),
  );
