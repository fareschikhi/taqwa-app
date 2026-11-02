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
  UseGuards,
} from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
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
import {
  ChatPageQuery,
  ChatSearchQuery,
  EditChatMessageDto,
  SendChatMessageDto,
} from './dto/chat.dto';

/** Sends per user per minute: plenty for a person, a wall for a script. */
const SEND_LIMIT = { default: { limit: 30, ttl: 60_000 } };

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
  constructor(private chat: ChatService) {}

  // ── Parent ────────────────────────────────────────────────────────────────

  @Get('me/messages')
  @Roles(Role.PARENT)
  parentMessages(@CurrentUser() user: ChatUser, @Query() query: ChatPageQuery) {
    return this.chat.parentPage(user, query);
  }

  @Post('me/messages')
  @Roles(Role.PARENT)
  @Throttle(SEND_LIMIT)
  parentSend(@CurrentUser() user: ChatUser, @Body() dto: SendChatMessageDto) {
    return this.chat.parentSend(user, dto);
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
  staffSend(
    @CurrentUser() user: ChatUser,
    @Param('parentId', ParseIntPipe) parentId: number,
    @Body() dto: SendChatMessageDto,
  ) {
    return this.chat.staffSend(user, parentId, dto);
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

  @Delete('messages/:id')
  @Roles(Role.PARENT, Role.ADMIN, Role.MANAGER)
  remove(@CurrentUser() user: ChatUser, @Param('id', ParseIntPipe) id: number) {
    return this.chat.remove(user, id);
  }
}
