import { applyDecorators } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { Transform } from 'class-transformer';
import {
  ArrayMaxSize,
  IsArray,
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  Matches,
  MaxLength,
  MinLength,
  ValidateIf,
} from 'class-validator';

/**
 * A phone in its stored form: an Algerian number in local form ("0551234567",
 * how every existing account is stored and matched at login), or any other
 * country's number in international form ("+33612345678"). The length is
 * loose on purpose, since numbering plans differ, but stays within E.164's 15
 * digits.
 */
export const STORED_PHONE = /^(?:0\d{6,14}|\+[1-9]\d{6,14})$/;

export const PHONE_ERROR = 'رقم الهاتف غير صالح';

/**
 * Strips spacing/punctuation, turns a 00 prefix into +, and folds +213 into
 * the local 0 prefix (dropping a trunk 0 typed after the code), so
 * "+213 551 23 45 67", "+213 0551..." and "0551234567" are stored — and
 * matched at login — as the same string. Anything else is left for the format
 * check to judge.
 */
export function normalizePhone(value: unknown): unknown {
  if (typeof value !== 'string') return value;
  const compact = value.replace(/[\s\-.()]/g, '').replace(/^00/, '+');
  const algerian = /^\+2130?(\d+)$/.exec(compact);
  return algerian ? `0${algerian[1]}` : compact;
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
    Matches(STORED_PHONE, { message: PHONE_ERROR }),
  );

/** How many numbers the + button may add beside the main phone. */
export const MAX_EXTRA_PHONES = 4;

/**
 * Extra contact numbers beside the login phone. Each is normalized like the
 * main one and blank rows are dropped, so an empty box left by the + button
 * never fails the save. [] clears them; omitting the field leaves them as
 * they are.
 */
export const IsExtraPhones = () =>
  applyDecorators(
    IsOptional(),
    Transform(({ value }) =>
      Array.isArray(value)
        ? value.map(normalizePhone).filter((v) => v !== '')
        : value,
    ),
    IsArray(),
    ArrayMaxSize(MAX_EXTRA_PHONES, { message: 'عدد أرقام الهاتف كبير جداً' }),
    IsString({ each: true }),
    Matches(STORED_PHONE, { each: true, message: PHONE_ERROR }),
  );

/**
 * The column value for validated extra phones: repeats and the main phone
 * itself are dropped, and an empty list is stored as NULL.
 */
export function extraPhonesData(
  extraPhones: string[],
  mainPhone?: string | null,
): string[] | typeof Prisma.DbNull {
  const main = mainPhone?.trim();
  const list = [...new Set(extraPhones)].filter((p) => p !== main);
  return list.length > 0 ? list : Prisma.DbNull;
}

export const IsOptionalEmail = () =>
  applyDecorators(
    IsOptional(),
    trim(),
    ValidateIf((_, value) => value !== ''),
    IsEmail({}, { message: 'البريد الإلكتروني غير صالح' }),
  );
