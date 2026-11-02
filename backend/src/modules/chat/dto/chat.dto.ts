import { Type } from 'class-transformer';
import {
  IsISO8601,
  IsInt,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  Min,
} from 'class-validator';

export const MAX_BODY_LENGTH = 2000;

/** Which slice of a thread to return; neither means "the newest page". */
export class ChatPageQuery {
  /** Older messages, before this id (scrolling up). */
  @IsOptional() @Type(() => Number) @IsInt() @Min(1) before?: number;

  /**
   * Everything that changed after this instant: new, edited and deleted
   * messages. An open thread polls with the `serverTime` of its last page.
   */
  @IsOptional() @IsISO8601() since?: string;
}

export class ChatSearchQuery {
  @IsOptional() @IsString() @MaxLength(100) search?: string;
}

/** Multipart or JSON; the photo, when there is one, arrives as a file. */
export class SendChatMessageDto {
  @IsOptional() @IsString() @MaxLength(MAX_BODY_LENGTH) body?: string;
}

export class EditChatMessageDto {
  @IsString() @IsNotEmpty() @MaxLength(MAX_BODY_LENGTH) body: string;
}
