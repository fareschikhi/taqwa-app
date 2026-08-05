import { IsDateString, IsInt, IsOptional, IsString } from 'class-validator';

export class CreateStudentDto {
  @IsString() fullName: string;
  @IsOptional() @IsString() phone?: string;
  @IsString() address: string;
  @IsDateString() birthDate: string;
  @IsOptional() @IsString() password?: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
}

export class UpdateStudentDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsDateString() birthDate?: string;
  @IsOptional() @IsString() password?: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
}
