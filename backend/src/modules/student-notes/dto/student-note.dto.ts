import { ArrayNotEmpty, IsArray, IsInt, IsString, IsOptional } from 'class-validator';

export class CreateStudentNoteDto {
  @IsInt() studentId: number;
  @IsInt() teacherId: number;
  @IsString() note: string;
}

// One note addressed to several students at once ("all students" in the
// teacher's picker). Each student still gets a row of their own, so the note
// shows on every child's page and each parent is told about their child.
export class CreateBulkStudentNoteDto {
  @IsArray() @ArrayNotEmpty() @IsInt({ each: true }) studentIds: number[];
  @IsInt() teacherId: number;
  @IsString() note: string;
}

export class UpdateStudentNoteDto {
  @IsOptional() @IsString() note?: string;
}
