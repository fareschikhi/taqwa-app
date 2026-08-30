import {
  IsEnum,
  IsInt,
  IsNotEmpty,
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
  // Auto-charges never go through this DTO — the attendance reconciliation
  // creates those directly with `reason: null` because `source` already says
  // why. A manual entry has nothing else to explain it, so this is the one
  // path where a reason is mandatory.
  @IsString() @IsNotEmpty() @MaxLength(300) reason: string;
}
