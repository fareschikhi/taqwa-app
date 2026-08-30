import {
  IsBoolean,
  IsDateString,
  IsInt,
  IsOptional,
  IsString,
  MinLength,
} from 'class-validator';

export class CreateStudentDto {
  @IsString() fullName: string;
  @IsOptional() @IsString() phone?: string;
  @IsString() address: string;
  @IsDateString() birthDate: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsBoolean() isAdult?: boolean;
  // Only meaningful with isAdult; the service rejects the pairing that makes
  // an account nobody can sign into.
  @IsOptional() @IsString() @MinLength(6) password?: string;
}

export class UpdateStudentDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() currentRating?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsDateString() birthDate?: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
}
