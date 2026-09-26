import { Transform } from 'class-transformer';
import { IsEmail, IsOptional, IsString, MinLength } from 'class-validator';
import { normalizePhone } from '../../../common/validators/account-fields';

export class LoginDto {
  @IsOptional()
  @IsEmail()
  email?: string;

  // Normalized exactly like account creation stores it, so "+213 551..." finds
  // "0551...". Deliberately no format check: older accounts (the seed's short
  // ids among them) must still be able to sign in.
  @IsOptional()
  @Transform(({ value }) => normalizePhone(value))
  @IsString()
  phone?: string;

  @IsString()
  @MinLength(6)
  password: string;
}
