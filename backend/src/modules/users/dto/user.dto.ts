import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, MaxLength, ValidateIf } from 'class-validator';
import { Role } from '@prisma/client';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';

export class CreateUserDto {
  @IsFullName()
  fullName: string;

  @IsOptionalEmail()
  email?: string;

  @IsOptionalPhone()
  phone?: string;

  @IsPassword()
  password: string;

  @IsEnum(Role)
  role: Role;

  @IsOptional()
  @IsString()
  avatar?: string;
}

export class UpdateUserDto {
  @IsOptional()
  @IsFullName()
  fullName?: string;

  @IsOptionalEmail()
  email?: string;

  @IsOptionalPhone()
  phone?: string;

  @IsOptional()
  @IsPassword()
  password?: string;

  @IsOptional()
  @IsString()
  avatar?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}

/// Fields a signed-in user may change on their own account. Deliberately
/// omits role, isActive and password: with `whitelist: true` on the global
/// pipe those are stripped from the body, so this endpoint cannot be used to
/// self-promote. Passwords go through PATCH /auth/password instead.
export class UpdateMeDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() phone?: string;

  // ValidateIf, not IsOptional alone: an empty string is how the client clears
  // an email, and @IsEmail would reject it before the service could null it.
  @IsOptional()
  @ValidateIf((o: UpdateMeDto) => o.email !== '')
  @IsEmail()
  email?: string;

  /// The path /uploads returned for a freshly picked photo.
  @IsOptional() @IsString() @MaxLength(500) avatar?: string;
}
