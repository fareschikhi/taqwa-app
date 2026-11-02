import { IsArray, IsEnum, IsInt, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { AttendanceStatus } from '@prisma/client';

// "Did not memorize" is not accepted from the client: the server derives it
// from whether a recitation was recorded that day (see day-fines.ts). Older
// app builds still send `missedMemorization`; the global ValidationPipe runs
// with `whitelist: true`, so the stray field is stripped rather than refused.
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
