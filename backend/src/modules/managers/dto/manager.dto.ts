import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateManagerDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsPassword() password: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
  @IsOptional() @IsBoolean() canAccessUnassigned?: boolean;
}

export class UpdateManagerDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
  @IsOptional() @IsBoolean() canAccessUnassigned?: boolean;
}

export class UpdateManagerStatusDto {
  @IsBoolean() isActive: boolean;
}
