import { IsOptional, IsString } from 'class-validator';

export class CreateParentDto {
  @IsString() fullName: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsString() password: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
}

export class UpdateParentDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() phone?: string;
  @IsOptional() @IsString() password?: string;
  @IsOptional() @IsString() address?: string;
  @IsOptional() @IsString() avatar?: string;
}
