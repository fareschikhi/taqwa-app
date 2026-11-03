import {
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Max,
  MaxLength,
  Min,
  NotEquals,
  ValidateBy,
  ValidationOptions,
} from 'class-validator';

// Two decimals at most, and at least a hundredth. class-validator's own
// IsNumber({ maxDecimalPlaces }) reads the digits after a '.' in String(v), and
// on "1e-7" (no '.') it throws a TypeError: a 500. Rounding to two places and
// comparing handles exponent notation as well.
const IsHundredths = (options?: ValidationOptions) =>
  ValidateBy(
    {
      name: 'isHundredths',
      validator: {
        validate: (v) =>
          typeof v !== 'number' ||
          v === 0 ||
          (Number(v.toFixed(2)) === v && Math.abs(v) >= 0.01),
        defaultMessage: () => 'رقمان بعد الفاصلة على الأكثر، وأقل قيمة 0.01',
      },
    },
    options,
  );

export class CreatePointsDto {
  @IsInt() userId: number;
  // Signed: the sign is the direction. Two decimals at most, so a teacher can
  // give half a point; the cap catches a slipped finger (5000 for 50) rather
  // than quietly obeying it.
  @IsNumber()
  @NotEquals(0)
  @IsHundredths()
  @Min(-1000)
  @Max(1000)
  amount: number;
  // Optional: an adjustment with no reason shows as a plain "تعديل يدوي".
  @IsOptional() @IsString() @MaxLength(300) reason?: string;
}
