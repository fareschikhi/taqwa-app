import {
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  NotEquals,
} from 'class-validator';

export class CreatePointsDto {
  @IsInt() userId: number;
  // Signed: the sign is the direction. Two decimals at most, so a teacher can
  // give half a point; the cap catches a slipped finger (5000 for 50) rather
  // than quietly obeying it.
  @IsNumber({ maxDecimalPlaces: 2 })
  @NotEquals(0)
  @Min(-1000)
  @Max(1000)
  amount: number;
  // Optional: an adjustment with no reason shows as a plain "تعديل يدوي".
  @IsOptional() @IsString() @MaxLength(300) reason?: string;
}
