import {
  IsEnum,
  IsInt,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';
import { FineKind } from '@prisma/client';

export class CreateFineDto {
  @IsInt() studentId: number;
  @IsEnum(FineKind) kind: FineKind;
  // Always positive; `kind` carries the direction. A zero entry would say
  // nothing, so the floor is 1.
  @IsInt() @Min(1) amount: number;
  // Optional: a manual entry with no reason is stored as `null` and shows as
  // a plain "تعديل" on the statement, the same fallback a blank one gets.
  @IsOptional() @IsString() @MaxLength(300) reason?: string;
}
