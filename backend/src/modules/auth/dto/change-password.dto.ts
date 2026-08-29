import { IsString, MinLength } from 'class-validator';

export class ChangePasswordDto {
  @IsString() currentPassword: string;

  // The global ValidationPipe turns this into a 400 before the service runs,
  // so the service never re-checks the length.
  @IsString() @MinLength(6) newPassword: string;
}
