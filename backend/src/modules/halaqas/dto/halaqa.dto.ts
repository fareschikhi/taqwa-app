import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateHalaqaDto {
  @IsString() name: string;
  @IsOptional() @IsString() description?: string;
  @IsInt() teacherId: number;
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}

export class UpdateHalaqaDto {
  @IsOptional() @IsString() name?: string;
  @IsOptional() @IsString() description?: string;
  @IsOptional() @IsInt() teacherId?: number;
  @IsOptional() @IsBoolean() isStudentsChanged?: boolean;

  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}
