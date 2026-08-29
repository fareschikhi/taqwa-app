import { IsBoolean, IsEmail, IsEnum, IsOptional, IsString, MinLength, ValidateIf } from 'class-validator';
import { Role } from '@prisma/client';

export class CreateUserDto {
  @IsString()
  fullName: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsString()
  @MinLength(6)
  password: string;

  @IsEnum(Role)
  role: Role;

  @IsOptional()
  @IsString()
  avatar?: string;
}

export class UpdateUserDto {
  @IsOptional()
  @IsString()
  fullName?: string;

  @IsOptional()
  @IsEmail()
  email?: string;

  @IsOptional()
  @IsString()
  phone?: string;

  @IsOptional()
  @IsString()
  @MinLength(6)
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
}
