import {
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsOptional,
  IsString,
} from 'class-validator';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';
import { HALAQA_LEVELS } from '../../halaqas/dto/halaqa.dto';

export class CreateTeacherDto {
  @IsFullName() fullName: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsPassword() password: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsBoolean() canPostNews?: boolean;
  // The levels this teacher is معلم مشرف of (one of HALAQA_LEVELS each).
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsIn(HALAQA_LEVELS, { each: true })
  supervisedLevels?: string[];
}

export class UpdateTeacherDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsPassword() password?: string;
  @IsOptional() @IsDateString() hireDate?: string;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsBoolean() canPostNews?: boolean;
  // Replaces the whole set when sent; left out = unchanged; [] clears it.
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsIn(HALAQA_LEVELS, { each: true })
  supervisedLevels?: string[];
}
