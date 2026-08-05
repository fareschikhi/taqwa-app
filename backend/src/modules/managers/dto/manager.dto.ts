import {
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';

export class CreateManagerDto {
  @IsString() fullName: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsString() password: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
}

export class UpdateManagerDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() password?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsArray() @IsInt({ each: true }) halaqaIds?: number[];
  @IsOptional() @IsBoolean() canManageAccounts?: boolean;
  @IsOptional() @IsBoolean() canDeleteAccounts?: boolean;
}

export class UpdateManagerStatusDto {
  @IsBoolean() isActive: boolean;
}
