import { Type } from 'class-transformer';
import {
  ArrayMaxSize,
  ArrayNotEmpty,
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsInt,
  IsNumber,
  IsEnum,
  IsOptional,
  IsString,
  MaxLength,
  Min,
  Max,
  ValidateNested,
} from 'class-validator';
import {
  Memorization,
  MemorizationSubject,
  ProgressUnit,
} from '@prisma/client';
import { MAX_AMOUNT } from '../progress-unit';

/// A halaqa is a few dozen children at most; the cap only stops a runaway
/// request from holding one transaction open for thousands of rows.
export const MAX_GROUP_SIZE = 100;

export class CreateMemorizationDto {
  @IsInt()
  studentId: number;

  // QURAN-only, and optional even there: a Quran entry may record just an
  // amount ("3 pages") without naming the surah. A HADITH entry omits this.
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

  // What amountDone counts. Quran: PAGE (default) or AYAH. Hadith: HADITH
  // (default) or PAGE. A unit from the other subject is refused.
  @IsOptional()
  @IsEnum(ProgressUnit)
  unit?: ProgressUnit;

  // AYAH-only range inside surahNumber; amountDone must be the ayah count
  // (ayahTo - ayahFrom + 1). The service checks it against the surah.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahFrom?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahTo?: number;

  // A recitation outside the halaqa session: skips the absence check and
  // never touches the day's attendance fines. Set on creation only.
  @IsOptional()
  @IsBoolean()
  outsideSession?: boolean;
}

/// The fields one recitation shares across a whole group: everything a single
/// entry takes except who recited it. Quran only — hadith entries carry a book
/// assigned per student, so a group cannot share one.
export class GroupMemorizationEntryDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber?: number;

  @IsNumber({ allowNaN: false, allowInfinity: false })
  @Min(0.5)
  @Max(MAX_AMOUNT.PAGE)
  amountDone: number;

  @IsOptional()
  @IsEnum(Memorization)
  memorizationType?: Memorization;

  // PAGE (default) or AYAH; the service refuses a hadith unit.
  @IsOptional()
  @IsEnum(ProgressUnit)
  unit?: ProgressUnit;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahFrom?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahTo?: number;
}

/// One recitation applied to several students at once — a halaqa of small
/// children who all memorize the same ayahs. Each student still gets a row of
/// his own, so progress, points and fines read it like any other entry.
export class CreateGroupMemorizationDto {
  @IsArray()
  @ArrayNotEmpty()
  @ArrayMaxSize(MAX_GROUP_SIZE)
  @ArrayUnique()
  @IsInt({ each: true })
  studentIds: number[];

  @ValidateNested()
  @Type(() => GroupMemorizationEntryDto)
  entry: GroupMemorizationEntryDto;
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

  // What amountDone counts. Quran: PAGE (default) or AYAH. Hadith: HADITH
  // (default) or PAGE. A unit from the other subject is refused.
  @IsOptional()
  @IsEnum(ProgressUnit)
  unit?: ProgressUnit;

  // AYAH-only range inside surahNumber; amountDone must be the ayah count
  // (ayahTo - ayahFrom + 1). The service checks it against the surah.
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahFrom?: number;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.AYAH)
  ayahTo?: number;
}
