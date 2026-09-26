import { Transform } from 'class-transformer';
import { IsInt, IsNotEmpty, IsOptional, IsString, MaxLength } from 'class-validator';

/** Trims first, so a whitespace-only field fails IsNotEmpty rather than passing it. */
const trimmed = () =>
  Transform(({ value }) => (typeof value === 'string' ? value.trim() : value));

/** The news itself, for POST /all — the server supplies the halaqas. */
export class CreateAllHalaqasAnnouncementDto {
  @trimmed()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title: string;

  @trimmed()
  @IsString()
  @IsNotEmpty()
  body: string;
}

export class CreateHalaqaAnnouncementDto extends CreateAllHalaqasAnnouncementDto {
  @IsInt() halaqaId: number;
}

export class UpdateHalaqaAnnouncementDto {
  @IsOptional()
  @trimmed()
  @IsString()
  @IsNotEmpty()
  @MaxLength(200)
  title?: string;

  @IsOptional()
  @trimmed()
  @IsString()
  @IsNotEmpty()
  body?: string;
}
