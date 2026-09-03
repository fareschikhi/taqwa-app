import {
  IsInt,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
} from 'class-validator';
import { Memorization, MemorizationSubject } from '@prisma/client';
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

  // Pages for MEMORIZING Quran, hizbs for Quran revision, hadiths for any
  // hadith entry. This is only the coarse ceiling; the service applies the
  // tighter per-unit bound once it knows the subject and type.
  @IsInt()
  @Min(1)
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
}

export class UpdateMemorizationDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
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
}
