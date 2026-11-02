import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  Query,
  Res,
  UploadedFile,
  UseInterceptors,
  UseGuards,
  BadRequestException,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { Throttle } from '@nestjs/throttler';
import type { Response } from 'express';
import { Role } from '@prisma/client';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { RolesGuard } from '../../common/guards/roles.guard';
import { ManagerPermissionGuard } from '../../common/guards/manager-permission.guard';
import { Roles } from '../../common/decorators/roles.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import {
  ManagerPermission,
  RequirePermission,
} from '../../common/decorators/permissions.decorator';
import type { ChatUser } from './chat-access';
import { ChatService } from './chat.service';
import { ChatPhotos } from './chat-photos';
import {
  ChatPageQuery,
  ChatSearchQuery,
  EditChatMessageDto,
  SendChatMessageDto,
} from './dto/chat.dto';

/** Sends per user per minute: plenty for a person, a wall for a script. */
const SEND_LIMIT = { default: { limit: 30, ttl: 60_000 } };

const ALLOWED_MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

/** A `photo` multipart field: one image up to 5 MB, checked again by bytes. */
const photoUpload = FileInterceptor('photo', {
  limits: { fileSize: 5 * 1024 * 1024, files: 1 },
  fileFilter: (_req, file, callback) => {
    if (!ALLOWED_MIME_TYPES.includes(file.mimetype)) {
      callback(new BadRequestException('نوع الصورة غير مدعوم'), false);
      return;
    }
    callback(null, true);
  },
});

/**
 * Parent ↔ administration chat.
 *
 * `me/*` is the signed-in parent's own thread. `conversations`, `parents/*`
 * are the shared staff inbox: admins, and managers the admin granted chat.
 * The guards decide the role; the service decides the scope (which parents)
 * on every call, through chat-access.ts.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller('chat')
export class ChatController {
  constructor(
    private chat: ChatService,
    private photos: ChatPhotos,
  ) {}

  /**
   * Saves the optional photo, then sends. A send the service refuses (scope,
   * empty, deactivated parent) must not leave an orphan file behind.
   */
  private async withPhoto<T>(
    photo: Express.Multer.File | undefined,
    send: (imagePath?: string) => Promise<T>,
  ): Promise<T> {
    const imagePath = photo ? await this.photos.save(photo) : undefined;
    try {
      return await send(imagePath);
    } catch (e) {
      if (imagePath) await this.photos.deleteChatPhoto(imagePath);
      throw e;
    }
  }

  // ── Parent ────────────────────────────────────────────────────────────────

  @Get('me/messages')
  @Roles(Role.PARENT)
  parentMessages(@CurrentUser() user: ChatUser, @Query() query: ChatPageQuery) {
    return this.chat.parentPage(user, query);
  }

  @Post('me/messages')
  @Roles(Role.PARENT)
  @Throttle(SEND_LIMIT)
  @UseInterceptors(photoUpload)
  parentSend(
    @CurrentUser() user: ChatUser,
    @Body() dto: SendChatMessageDto,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    return this.withPhoto(photo, (path) =>
      this.chat.parentSend(user, dto, path),
    );
  }

  @Post('me/read')
  @Roles(Role.PARENT)
  parentRead(@CurrentUser() user: ChatUser) {
    return this.chat.parentRead(user);
  }

  @Get('me/unread')
  @Roles(Role.PARENT)
  parentUnread(@CurrentUser() user: ChatUser) {
    return this.chat.parentUnread(user);
  }

  // ── Staff ─────────────────────────────────────────────────────────────────

  @Get('conversations')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  inbox(@CurrentUser() user: ChatUser, @Query() query: ChatSearchQuery) {
    return this.chat.inbox(user, query.search);
  }

  // Declared before any ':param' route could shadow it.
  @Get('conversations/unread')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  staffUnread(@CurrentUser() user: ChatUser) {
    return this.chat.staffUnread(user);
  }

  @Get('parents')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  parents(@CurrentUser() user: ChatUser, @Query() query: ChatSearchQuery) {
    return this.chat.pickableParents(user, query.search);
  }

  @Get('parents/:parentId/messages')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  staffMessages(
    @CurrentUser() user: ChatUser,
    @Param('parentId', ParseIntPipe) parentId: number,
    @Query() query: ChatPageQuery,
  ) {
    return this.chat.staffPage(user, parentId, query);
  }

  @Post('parents/:parentId/messages')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  @Throttle(SEND_LIMIT)
  @UseInterceptors(photoUpload)
  staffSend(
    @CurrentUser() user: ChatUser,
    @Param('parentId', ParseIntPipe) parentId: number,
    @Body() dto: SendChatMessageDto,
    @UploadedFile() photo?: Express.Multer.File,
  ) {
    return this.withPhoto(photo, (path) =>
      this.chat.staffSend(user, parentId, dto, path),
    );
  }

  @Post('parents/:parentId/read')
  @Roles(Role.ADMIN, Role.MANAGER)
  @RequirePermission(ManagerPermission.CHAT)
  @UseGuards(ManagerPermissionGuard)
  staffRead(
    @CurrentUser() user: ChatUser,
    @Param('parentId', ParseIntPipe) parentId: number,
  ) {
    return this.chat.staffRead(user, parentId);
  }

  // ── Both sides ────────────────────────────────────────────────────────────

  // Who may change which message (own side only) is the service's call; a
  // manager without chat is refused by its scope check, not by a guard here,
  // since a parent has no `manager` to check.
  @Patch('messages/:id')
  @Roles(Role.PARENT, Role.ADMIN, Role.MANAGER)
  edit(
    @CurrentUser() user: ChatUser,
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: EditChatMessageDto,
  ) {
    return this.chat.edit(user, id, dto);
  }

  /**
   * A chat photo, after the same scope check as its thread. Cached privately
   * by the phone only: a shared cache must never hold a medical note.
   */
  @Get('photos/:messageId')
  @Roles(Role.PARENT, Role.ADMIN, Role.MANAGER)
  async photo(
    @CurrentUser() user: ChatUser,
    @Param('messageId', ParseIntPipe) messageId: number,
    @Res() res: Response,
  ) {
    this.photos.serve(res, await this.chat.photoPathFor(user, messageId));
  }

  @Delete('messages/:id')
  @Roles(Role.PARENT, Role.ADMIN, Role.MANAGER)
  remove(@CurrentUser() user: ChatUser, @Param('id', ParseIntPipe) id: number) {
    return this.chat.remove(user, id);
  }
}
