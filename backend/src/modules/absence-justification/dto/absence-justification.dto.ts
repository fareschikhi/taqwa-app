import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
} from 'class-validator';
import { JustificationReasonType } from '@prisma/client';

export class CreateAbsenceJustificationDto {
  @IsInt() studentId: number;
  @IsInt() attendanceId: number;
  @IsInt() managerId: number;
  @IsEnum(JustificationReasonType) reasonType: JustificationReasonType;
  @IsOptional() @IsString() customReason?: string;
  @IsOptional() @IsString() notes?: string;
}

export class UpdateAbsenceJustificationDto {
  @IsOptional() @IsEnum(JustificationReasonType) reasonType?: JustificationReasonType;
  @IsOptional() @IsString() customReason?: string;
  @IsOptional() @IsString() notes?: string;
}
