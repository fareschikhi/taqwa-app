import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';
import {
  IsExtraPhones,
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateManagerDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsExtraPhones() extraPhones?: string[];
  @IsPassword() password: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
  @IsOptional() @IsBoolean() canAccessUnassigned?: boolean;
  @IsOptional() @IsBoolean() canChat?: boolean;
}

export class UpdateManagerDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsExtraPhones() extraPhones?: string[];
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
  @IsOptional() @IsBoolean() canAccessUnassigned?: boolean;
  @IsOptional() @IsBoolean() canChat?: boolean;
}

export class UpdateManagerStatusDto {
  @IsBoolean() isActive: boolean;
}
