import {
  IsArray,
  IsBoolean,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  Min,
  ValidateIf,
} from 'class-validator';

// A halaqa's category (the `level` column). The Arabic label itself is what
// is stored, so every screen that already prints `level` shows it as-is. It is
// independent of `isAdult`: a جامعي halaqa only runs on fines if the admin
// turns that on. Keep in step with kHalaqaLevels in the Flutter app.
export const HALAQA_LEVELS = [
  'ابتدائي',
  'متوسط',
  'ثانوي',
  'جامعي (كبار)',
] as const;

export class CreateHalaqaDto {
  @IsString() name: string;
  @IsIn(HALAQA_LEVELS) level: string;
  @IsInt() teacherId: number;
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];

  @IsOptional() @IsBoolean() isAdult?: boolean;
  // Whole dinars. Zero is a real setting — a halaqa that charges for absence
  // but not for lateness — so the floor is 0, not 1.
  @IsOptional() @IsInt() @Min(0) absenceFee?: number;
  @IsOptional() @IsInt() @Min(0) lateFee?: number;
  @IsOptional() @IsInt() @Min(0) missedMemorizationFee?: number;
  // Charged per repeat (إعادة) recitation.
  @IsOptional() @IsInt() @Min(0) repeatFee?: number;
}

export class UpdateHalaqaDto {
  @IsOptional() @IsString() name?: string;
  // Left out = unchanged. Null is rejected rather than waved through the way
  // @IsOptional() would: every halaqa must keep a category once it has one.
  @ValidateIf((o: UpdateHalaqaDto) => o.level !== undefined)
  @IsIn(HALAQA_LEVELS)
  level?: string;
  @IsOptional() @IsInt() teacherId?: number;

  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];

  @IsOptional() @IsBoolean() isAdult?: boolean;
  @IsOptional() @IsInt() @Min(0) absenceFee?: number;
  @IsOptional() @IsInt() @Min(0) lateFee?: number;
  @IsOptional() @IsInt() @Min(0) missedMemorizationFee?: number;
  @IsOptional() @IsInt() @Min(0) repeatFee?: number;
}
