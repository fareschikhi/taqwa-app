import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export class CreateHalaqaDto {
  @IsString() name: string;
  @IsOptional() @IsString() @MaxLength(100) level?: string;
  @IsInt() teacherId: number;
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];

  @IsOptional() @IsBoolean() isAdult?: boolean;
  // Whole dinars. Zero is a real setting — a halaqa that charges for absence
  // but not for lateness — so the floor is 0, not 1.
  @IsOptional() @IsInt() @Min(0) absenceFee?: number;
  @IsOptional() @IsInt() @Min(0) lateFee?: number;
  @IsOptional() @IsInt() @Min(0) missedMemorizationFee?: number;
}

export class UpdateHalaqaDto {
  @IsOptional() @IsString() name?: string;
  // Null clears the column: @IsOptional() waves null past @IsString(), and
  // Prisma writes it straight through as NULL.
  @IsOptional() @IsString() @MaxLength(100) level?: string | null;
  @IsOptional() @IsInt() teacherId?: number;

  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];

  @IsOptional() @IsBoolean() isAdult?: boolean;
  @IsOptional() @IsInt() @Min(0) absenceFee?: number;
  @IsOptional() @IsInt() @Min(0) lateFee?: number;
  @IsOptional() @IsInt() @Min(0) missedMemorizationFee?: number;
}
