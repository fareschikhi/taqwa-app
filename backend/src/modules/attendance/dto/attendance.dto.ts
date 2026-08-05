import { IsArray, IsEnum, IsInt, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { AttendanceStatus } from '@prisma/client';

export class CreateAttendanceDto {
  @IsInt() studentId: number;
  @IsString() date: string; // ISO date string YYYY-MM-DD
  @IsEnum(AttendanceStatus) status: AttendanceStatus;
  @IsOptional() @IsString() notes?: string;
}

export class UpdateAttendanceDto {
  @IsOptional() @IsEnum(AttendanceStatus) status?: AttendanceStatus;
  @IsOptional() @IsString() notes?: string;
}

export class CreateBatchAttendanceDto {
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => CreateAttendanceDto)
  records: CreateAttendanceDto[];
}
