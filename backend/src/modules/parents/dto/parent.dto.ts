import { IsOptional, IsString } from 'class-validator';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateParentDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsPassword() password: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
}

export class UpdateParentDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
}
