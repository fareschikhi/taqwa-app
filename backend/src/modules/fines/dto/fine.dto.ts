import { IsEnum, IsInt, IsOptional, IsString, MaxLength, Min } from 'class-validator';
import { FineKind } from '@prisma/client';

export class CreateFineDto {
  @IsInt() studentId: number;
  @IsEnum(FineKind) kind: FineKind;
  // Always positive; `kind` carries the direction. A zero entry would say
  // nothing, so the floor is 1.
  @IsInt() @Min(1) amount: number;
  @IsOptional() @IsString() @MaxLength(300) reason?: string;
}
