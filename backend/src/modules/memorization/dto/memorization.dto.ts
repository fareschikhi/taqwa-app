import { IsInt, IsEnum, IsOptional, Min, Max } from 'class-validator';
import { Memorization } from '@prisma/client';
import { MAX_AMOUNT } from '../progress-unit';

export class CreateMemorizationDto {
  @IsInt()
  studentId: number;

  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber: number;

  // Pages for MEMORIZING, hizbs for either revision. This is only the coarse
  // ceiling; the service applies the tighter per-unit bound once it knows the
  // memorization type.
  @IsInt()
  @Min(1)
  @Max(MAX_AMOUNT.PAGE)
  amountDone: number;

  @IsOptional()
  @IsEnum(Memorization)
  memorizationType?: Memorization;
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
}
