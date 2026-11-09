import { IsArray, IsEnum, IsInt, IsOptional, IsString, Max, Min, ValidateNested } from 'class-validator';
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

  // What the teacher chose to charge for this late arrival, in DA. Only read
  // when status is LATE; 0 waives it. Left out (older app builds), the
  // halaqa's own late fee applies as before.
  @IsOptional() @IsInt() @Min(0) @Max(100000) lateFee?: number;
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
