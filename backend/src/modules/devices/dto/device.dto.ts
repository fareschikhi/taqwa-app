import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  /** The FCM registration token. Capped to the column it is stored in. */
  @IsString() @MaxLength(255) token: string;

  /**
   * Optional so unregistering can reuse this DTO — signing out identifies a
   * device by its token alone.
   */
  @IsOptional() @IsIn(['android', 'ios']) platform?: string;
}
