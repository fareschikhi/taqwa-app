import {
  ArrayUnique,
  IsArray,
  IsBoolean,
  IsDateString,
  IsIn,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
} from 'class-validator';
import {
  IsFullName,
  IsOptionalEmail,
  IsOptionalPhone,
  IsPassword,
} from '../../../common/validators/account-fields';
import { HADITH_BOOKS } from '../hadith-books';

/// The registration-form (استمارة التسجيل) details, shared by create and
/// update. Every one is optional; lengths match the `students` columns.
export class StudentRegistrationDto {
  @IsOptional() @IsString() @MaxLength(100) schoolLevel?: string;
  @IsOptional() @IsString() @MaxLength(255) healthStatus?: string;
  @IsOptional() @IsString() @MaxLength(255) familyStatus?: string;
  @IsOptional() @IsString() @MaxLength(100) fatherJob?: string;
  @IsOptional() @IsString() @MaxLength(100) motherJob?: string;
  @IsOptional() @IsString() @MaxLength(100) occupation?: string;
  @IsOptional() @IsString() @MaxLength(255) externalActivities?: string;
  @IsOptional() @IsBoolean() isMarried?: boolean;
}

export class CreateStudentDto extends StudentRegistrationDto {
  @IsFullName() fullName: string;
  @IsOptionalPhone() phone?: string;
  // The adults' form asks for it; a child's record has no use for one.
  @IsOptionalEmail() email?: string;
  @IsOptional() @IsString() address?: string;
  @IsDateString() birthDate: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional() @IsBoolean() isAdult?: boolean;
  // The admin's pick of hadith books for this student; an empty list turns
  // hadith off. Gates the Hadith subject on the recitation sheet and the
  // server-side hadith write path.
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsIn(HADITH_BOOKS, { each: true })
  hadithBooks?: string[];
  // Only meaningful with isAdult; the service rejects the pairing that makes
  // an account nobody can sign into.
  @IsOptional() @IsPassword() password?: string;
}

export class UpdateStudentDto extends StudentRegistrationDto {
  @IsOptional() @IsFullName() fullName?: string;
  @IsOptional() @IsString() currentRating?: string;
  @IsOptionalEmail() email?: string;
  @IsOptionalPhone() phone?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsDateString() birthDate?: string;
  @IsOptional() @IsInt() parentId?: number;
  @IsOptional() @IsInt() halaqaId?: number;
  @IsOptional() @IsString() avatar?: string;
  @IsOptional()
  @IsArray()
  @ArrayUnique()
  @IsIn(HADITH_BOOKS, { each: true })
  hadithBooks?: string[];
}
