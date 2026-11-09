import { IsArray, IsInt, IsOptional, IsString } from 'class-validator';
import {
  IsExtraPhones,
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateParentDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsExtraPhones() extraPhones?: string[];
  @IsPassword() password: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}

export class UpdateParentDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsExtraPhones() extraPhones?: string[];
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
  // Replaces the parent's children; omit it to leave them as they are.
  @IsOptional() @IsArray() @IsInt({ each: true }) studentIds?: number[];
}
