import { IsInt, IsString, IsOptional } from 'class-validator';

export class CreateStudentNoteDto {
  @IsInt() studentId: number;
  @IsInt() teacherId: number;
  @IsString() note: string;
}

export class UpdateStudentNoteDto {
  @IsOptional() @IsString() note?: string;
}
