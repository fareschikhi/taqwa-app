import { IsInt, IsEnum, IsOptional, Min, Max } from 'class-validator';
import { Memorization } from '@prisma/client';

export class CreateMemorizationDto {
  @IsInt()
  studentId: number;

  @IsInt()
  @Min(1)
  @Max(114)
  surahNumber: number;

  @IsInt()
  @Min(1)
  pagesDone: number;

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
  pagesDone?: number;

  @IsOptional()
  @IsEnum(Memorization)
  memorizationType?: Memorization;
}
