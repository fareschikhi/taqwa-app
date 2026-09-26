import { IsDateString, IsOptional, IsString } from 'class-validator';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateTeacherDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsPassword() password: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
}

export class UpdateTeacherDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
}
