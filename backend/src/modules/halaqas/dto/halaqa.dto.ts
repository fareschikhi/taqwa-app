import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';

export class CreateHalaqaDto {
  @IsString() name: string;
  @IsOptional() @IsString() @MaxLength(100) level?: string;
  @IsInt() teacherId: number;
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}

export class UpdateHalaqaDto {
  @IsOptional() @IsString() name?: string;
  // Null clears the column: @IsOptional() waves null past @IsString(), and
  // Prisma writes it straight through as NULL.
  @IsOptional() @IsString() @MaxLength(100) level?: string | null;
  @IsOptional() @IsInt() teacherId?: number;

  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}
