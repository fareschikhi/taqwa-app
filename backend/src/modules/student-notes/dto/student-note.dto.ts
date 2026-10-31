import { Transform } from 'class-transformer';
import { ArrayNotEmpty, IsArray, IsInt, IsString, IsOptional } from 'class-validator';
import { normalizeNoteText } from '../note-text';

/** Cuts runs of blank lines before the note is stored; see normalizeNoteText. */
const noteText = () =>
  Transform(({ value }) => (typeof value === 'string' ? normalizeNoteText(value) : value));

export class CreateStudentNoteDto {
  @IsInt() studentId: number;
  @IsInt() teacherId: number;
  @noteText() @IsString() note: string;
}

// One note addressed to several students at once ("all students" in the
// teacher's picker). It is stored once with a recipient per student, so it
// shows on every child's page and each parent is told about their child.
export class CreateBulkStudentNoteDto {
  @IsArray() @ArrayNotEmpty() @IsInt({ each: true }) studentIds: number[];
  @IsInt() teacherId: number;
  @noteText() @IsString() note: string;
}

export class UpdateStudentNoteDto {
  @IsOptional() @noteText() @IsString() note?: string;
}
