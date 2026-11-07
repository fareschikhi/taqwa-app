import {
  IsInt,
  IsNumber,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Memorization, MemorizationSubject, ProgressUnit } from '@prisma/client';
import { MAX_AMOUNT } from '../progress-unit';

export class CreateMemorizationDto {
  @IsInt()
  studentId: number;

  // QURAN-only; a HADITH entry omits this.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber?: number;

  // Pages for any Quran entry, hadiths for any hadith entry. This is only the
  // coarse ceiling; the service applies the tighter per-unit bound once it
  // knows the subject, including which units may take a half (only pages do).
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(0.5)
  @Max(MAX_AMOUNT.PAGE)
  amountDone: number;

  @IsOptional()
  @IsEnum(Memorization)
  memorizationType?: Memorization;

  // Defaults to QURAN on the service side when omitted, so every existing
  // caller keeps working unchanged.
  @IsOptional()
  @IsEnum(MemorizationSubject)
  subject?: MemorizationSubject;

  // HADITH-only free-text identity; a QURAN entry omits this.
  @IsOptional()
  @IsString()
  @MaxLength(500)
  hadithReference?: string;

  // HADITH-only choice of what amountDone counts; omitted means single
  // hadiths. A Quran entry is always pages and refuses HADITH.
  @IsOptional()
  @IsEnum(ProgressUnit)
  unit?: ProgressUnit;
}

export class UpdateMemorizationDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber?: number;

  @IsOptional()
  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(0.5)
  @Max(MAX_AMOUNT.PAGE)
  amountDone?: number;

  @IsOptional()
  @IsEnum(Memorization)
  memorizationType?: Memorization;

  @IsOptional()
  @IsEnum(MemorizationSubject)
  subject?: MemorizationSubject;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  hadithReference?: string;

  // HADITH-only choice of what amountDone counts; omitted means single
  // hadiths. A Quran entry is always pages and refuses HADITH.
  @IsOptional()
  @IsEnum(ProgressUnit)
  unit?: ProgressUnit;
}
