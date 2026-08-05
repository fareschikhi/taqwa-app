import { IsBoolean, IsInt, IsOptional, IsString } from 'class-validator';

export class CreateNotificationDto {
  @IsInt() userId: number;
  @IsString() title: string;
  @IsString() body: string;
}

export class UpdateNotificationDto {
  @IsOptional() @IsBoolean() isRead?: boolean;
}
