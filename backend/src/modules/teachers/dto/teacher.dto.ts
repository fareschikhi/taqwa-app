import { IsBoolean, IsDateString, IsOptional, IsString } from 'class-validator';
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
  @IsOptional() @IsBoolean() canPostNews?: boolean;
  // No isSupervisor here: a new teacher runs no halaqa yet, so he has no
  // level to supervise. The admin switches it on after assigning one.
}

export class UpdateTeacherDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsBoolean() canPostNews?: boolean;
  // معلم مشرف of the level of his halaqas. Turning it on needs a halaqa
  // with a level; turning it off is always allowed.
  @IsOptional() @IsBoolean() isSupervisor?: boolean;
}
