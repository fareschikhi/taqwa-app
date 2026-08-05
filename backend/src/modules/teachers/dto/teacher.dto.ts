import { IsDateString, IsOptional, IsString } from 'class-validator';

export class CreateTeacherDto {
  @IsString() fullName: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsString() password: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
}

export class UpdateTeacherDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() password?: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
}
