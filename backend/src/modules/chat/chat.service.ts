import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  halaqaIdsMatching,
  userIdsMatching,
} from '../../common/search/name-search';
import {
  canStaffSeeParent,
  chatParentIdForParentUser,
  chatParentWhere,
  chatScope,
  ChatUser,
} from './chat-access';
import { ChatNotifier } from './chat-notifier';
import { ChatPhotos } from './chat-photos';
import {
  ChatMessageDto,
  ChatViewer,
  messageText,
  previewOf,
  toMessageDto,
} from './chat-serializer';
import {
  ChatPageQuery,
  EditChatMessageDto,
  SendChatMessageDto,
} from './dto/chat.dto';

/** Newest-page size; older pages load as the user scrolls up. */
export const PAGE_SIZE = 30;
/** Inbox and parent-picker length. A school has a few hundred parents. */
const LIST_LIMIT = 100;
/**
 * How far a poll looks back past its `since`. Prisma stamps `updatedAt` when
 * a write is built, not when its transaction commits, so a row can carry a
 * time before the previous poll's serverTime yet only become visible after
 * it. Re-reading a few seconds is cheap: the app merges by id.
 */
export const SINCE_OVERLAP_MS = 5000;

const NO_ACCESS = 'غير مصرح لك بهذه المحادثة';

export interface ChatPage {
  messages: ChatMessageDto[];
  /** Pass back as `since` on the next poll. */
  serverTime: Date;
  hasMore: boolean;
}

export interface ChatInboxItem {
  parentId: number;
  parentName: string;
  parentAvatar: string | null;
  children: {
    id: number;
    fullName: string;
    halaqaId: number | null;
    halaqaName: string | null;
    /** Inside this viewer's chat scope: the inbox groups by these halaqas. */
    inScope: boolean;
  }[];
  lastMessage: { preview: string; fromStaff: boolean; at: Date } | null;
  unread: number;
}

const messageInclude = { sender: { select: { fullName: true } } } as const;

@Injectable()
export class ChatService {
  constructor(
    private prisma: PrismaService,
    private notifier: ChatNotifier,
    private photos: ChatPhotos,
  ) {}

  // ── Access ────────────────────────────────────────────────────────────────

  /** The parent's own thread id, or 403 (not a parent, or no child linked). */
  private async ownParentId(user: ChatUser): Promise<number> {
    const parentId = await chatParentIdForParentUser(this.prisma, user);
    if (!parentId) throw new ForbiddenException(NO_ACCESS);
    return parentId;
  }

  private async assertStaffScope(user: ChatUser, parentId: number) {
    if (!(await canStaffSeeParent(this.prisma, user, parentId))) {
      throw new ForbiddenException(NO_ACCESS);
    }
  }

  private loadParent(parentId: number) {
    return this.prisma.parent.findUnique({
      where: { id: parentId },
      select: {
        id: true,
        user: { select: { id: true, fullName: true, isActive: true } },
        chatConversation: { select: { id: true } },
      },
    });
  }

  // ── Reading ───────────────────────────────────────────────────────────────

  async parentPage(user: ChatUser, query: ChatPageQuery) {
    return this.page(await this.ownParentId(user), { isStaff: false }, query);
  }

  async staffPage(user: ChatUser, parentId: number, query: ChatPageQuery) {
    await this.assertStaffScope(user, parentId);
    return this.page(parentId, { isStaff: true }, query);
  }

  private async page(
    parentId: number,
    viewer: ChatViewer,
    query: ChatPageQuery,
  ): Promise<ChatPage> {
    // Taken before the query: a change landing while it runs is then seen
    // again on the next poll rather than missed.
    const serverTime = new Date();
    const parent = await this.loadParent(parentId);
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');

    const conversationId = parent.chatConversation?.id;
    if (!conversationId) return { messages: [], serverTime, hasMore: false };

    const toDto = (m: Parameters<typeof toMessageDto>[0]) =>
      toMessageDto(m, viewer, parent.user.fullName);

    if (query.since) {
      const changed = await this.prisma.chatMessage.findMany({
        where: {
          conversationId,
          updatedAt: {
            gte: new Date(new Date(query.since).getTime() - SINCE_OVERLAP_MS),
          },
        },
        orderBy: { id: 'asc' },
        include: messageInclude,
      });
      return { messages: changed.map(toDto), serverTime, hasMore: false };
    }

    const rows = await this.prisma.chatMessage.findMany({
      where: {
        conversationId,
        ...(query.before ? { id: { lt: query.before } } : {}),
      },
      orderBy: { id: 'desc' },
      take: PAGE_SIZE + 1,
      include: messageInclude,
    });
    const hasMore = rows.length > PAGE_SIZE;
    const messages = rows.slice(0, PAGE_SIZE).reverse().map(toDto);
    return { messages, serverTime, hasMore };
  }

  // ── Sending ───────────────────────────────────────────────────────────────

  async parentSend(
    user: ChatUser,
    dto: SendChatMessageDto,
    imagePath?: string,
  ) {
    const parentId = await this.ownParentId(user);
    return this.send(user, parentId, false, dto, imagePath);
  }

  async staffSend(
    user: ChatUser,
    parentId: number,
    dto: SendChatMessageDto,
    imagePath?: string,
  ) {
    await this.assertStaffScope(user, parentId);
    return this.send(user, parentId, true, dto, imagePath);
  }

  private async send(
    user: ChatUser,
    parentId: number,
    fromStaff: boolean,
    dto: SendChatMessageDto,
    imagePath?: string,
  ): Promise<ChatMessageDto> {
    const body = dto.body?.trim() || null;
    if (!body && !imagePath) {
      throw new BadRequestException('الرسالة فارغة');
    }

    const parent = await this.loadParent(parentId);
    if (!parent) throw new NotFoundException('ولي الأمر غير موجود');
    // History stays readable, but nobody can be written to who can't sign in
    // to read it.
    if (!parent.user.isActive) {
      // 409, not 403: the thread is still theirs to read, and the app reads
      // 403 as "access lost" and leaves the screen.
      throw new ConflictException('حساب ولي الأمر غير مفعل، لا يمكن مراسلته');
    }

    const message = await this.prisma.$transaction(async (tx) => {
      const now = new Date();
      // Created on the first message from either side, never on just opening.
      const conversation = await tx.chatConversation.upsert({
        where: { parentId },
        create: { parentId, lastMessageAt: now },
        update: { lastMessageAt: now },
      });
      const created = await tx.chatMessage.create({
        data: {
          conversationId: conversation.id,
          senderUserId: user.id,
          fromStaff,
          body,
          imagePath: imagePath ?? null,
        },
        include: messageInclude,
      });
      // Your own message is never unread for you.
      await this.moveReadMarker(tx, conversation.id, user.id, created.id);
      return created;
    });

    // Fire and forget: a slow or failing push must not delay or fail the send.
    void this.notifier.messageSent({
      parentId,
      parentUserId: parent.user.id,
      parentName: parent.user.fullName,
      fromStaff,
      text: messageText(message),
    });

    return toMessageDto(message, { isStaff: fromStaff }, parent.user.fullName);
  }

  // ── Read markers and unread counts ────────────────────────────────────────

  private moveReadMarker(
    tx: Prisma.TransactionClient,
    conversationId: number,
    userId: number,
    messageId: number,
  ) {
    return tx.chatRead.upsert({
      where: { conversationId_userId: { conversationId, userId } },
      create: { conversationId, userId, lastReadMessageId: messageId },
      update: { lastReadMessageId: messageId },
    });
  }

  async parentRead(user: ChatUser) {
    return this.markRead(user, await this.ownParentId(user));
  }

  async staffRead(user: ChatUser, parentId: number) {
    await this.assertStaffScope(user, parentId);
    return this.markRead(user, parentId);
  }

  private async markRead(user: ChatUser, parentId: number) {
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { parentId },
      select: { id: true },
    });
    if (!conversation) return { ok: true };
    const last = await this.prisma.chatMessage.findFirst({
      where: { conversationId: conversation.id },
      orderBy: { id: 'desc' },
      select: { id: true },
    });
    if (last) {
      await this.moveReadMarker(this.prisma, conversation.id, user.id, last.id);
    }
    return { ok: true };
  }

  /** Staff messages after the parent's marker. 0 when they may not chat. */
  async parentUnread(user: ChatUser) {
    const parentId = await chatParentIdForParentUser(this.prisma, user);
    if (!parentId) return { count: 0 };
    const conversation = await this.prisma.chatConversation.findUnique({
      where: { parentId },
      select: { id: true },
    });
    if (!conversation) return { count: 0 };
    const read = await this.prisma.chatRead.findUnique({
      where: {
        conversationId_userId: {
          conversationId: conversation.id,
          userId: user.id,
        },
      },
    });
    const count = await this.prisma.chatMessage.count({
      where: {
        conversationId: conversation.id,
        fromStaff: true,
        deletedAt: null,
        id: { gt: read?.lastReadMessageId ?? 0 },
      },
    });
    return { count };
  }

  /**
   * Parent messages after this staff member's own marker, over every thread
   * they may see. A colleague's reply never counts: it isn't something this
   * person has to answer.
   */
  async staffUnread(user: ChatUser) {
    const where = await chatParentWhere(this.prisma, user);
    if (!where) return { count: 0 };
    const conversations = await this.prisma.chatConversation.findMany({
      where: { parent: where },
      select: {
        id: true,
        reads: {
          where: { userId: user.id },
          select: { lastReadMessageId: true },
        },
      },
    });
    const counts = await this.unreadByConversation(conversations);
    let count = 0;
    counts.forEach((n) => (count += n));
    return { count };
  }

  /** One grouped query for many threads, each against its own marker. */
  private async unreadByConversation(
    conversations: { id: number; reads: { lastReadMessageId: number }[] }[],
  ): Promise<Map<number, number>> {
    const result = new Map<number, number>();
    if (!conversations.length) return result;
    const groups = await this.prisma.chatMessage.groupBy({
      by: ['conversationId'],
      where: {
        fromStaff: false,
        deletedAt: null,
        OR: conversations.map((c) => ({
          conversationId: c.id,
          id: { gt: c.reads[0]?.lastReadMessageId ?? 0 },
        })),
      },
      _count: { _all: true },
    });
    for (const g of groups) result.set(g.conversationId, g._count._all);
    return result;
  }

  // ── Inbox and parent picker ───────────────────────────────────────────────

  /** Threads with at least one message, most recent activity first. */
  async inbox(user: ChatUser, search: string | undefined) {
    return this.listParents(user, search, true);
  }

  /** Parents this user may start (or reopen) a thread with, by name. */
  async pickableParents(user: ChatUser, search: string | undefined) {
    return this.listParents(user, search, false);
  }

  private async listParents(
    user: ChatUser,
    search: string | undefined,
    withConversationOnly: boolean,
  ): Promise<ChatInboxItem[]> {
    const scope = await chatScope(this.prisma, user);
    if (!scope) throw new ForbiddenException(NO_ACCESS);

    const term = search?.trim();
    const and: Prisma.ParentWhereInput[] = [scope.where];
    if (term) {
      const [userIds, halaqaIds] = await Promise.all([
        userIdsMatching(this.prisma, term),
        halaqaIdsMatching(this.prisma, term),
      ]);
      and.push({
        OR: [
          { userId: { in: userIds } },
          { students: { some: { userId: { in: userIds } } } },
          { students: { some: { halaqaId: { in: halaqaIds } } } },
        ],
      });
    }
    if (withConversationOnly) and.push({ chatConversation: { isNot: null } });

    const parents = await this.prisma.parent.findMany({
      where: { AND: and },
      orderBy: withConversationOnly
        ? { chatConversation: { lastMessageAt: 'desc' } }
        : { user: { fullName: 'asc' } },
      take: LIST_LIMIT,
      select: {
        id: true,
        user: { select: { fullName: true, avatar: true } },
        students: {
          select: {
            id: true,
            user: { select: { fullName: true } },
            halaqa: { select: { id: true, name: true } },
          },
        },
        chatConversation: {
          select: {
            id: true,
            messages: { orderBy: { id: 'desc' }, take: 1 },
            reads: {
              where: { userId: user.id },
              select: { lastReadMessageId: true },
            },
          },
        },
      },
    });

    const unread = await this.unreadByConversation(
      parents.flatMap((p) => (p.chatConversation ? [p.chatConversation] : [])),
    );

    return parents.map((p) => {
      const last = p.chatConversation?.messages[0];
      return {
        parentId: p.id,
        parentName: p.user.fullName,
        parentAvatar: p.user.avatar,
        children: p.students.map((s) => ({
          id: s.id,
          fullName: s.user.fullName,
          halaqaId: s.halaqa?.id ?? null,
          halaqaName: s.halaqa?.name ?? null,
          inScope: scope.covers(s.halaqa?.id ?? null),
        })),
        lastMessage: last
          ? {
              preview: previewOf(last),
              fromStaff: last.fromStaff,
              at: last.createdAt,
            }
          : null,
        unread: p.chatConversation
          ? (unread.get(p.chatConversation.id) ?? 0)
          : 0,
      };
    });
  }

  // ── Edit and delete ───────────────────────────────────────────────────────

  async edit(user: ChatUser, messageId: number, dto: EditChatMessageDto) {
    const { message, viewer, parentName } = await this.loadOwnSide(
      user,
      messageId,
    );
    if (message.deletedAt) {
      throw new BadRequestException('لا يمكن تعديل رسالة محذوفة');
    }
    // Only text can change; a bare photo is deleted and sent again instead.
    if (message.body === null) {
      throw new BadRequestException('لا يمكن تعديل صورة بلا نص');
    }
    const updated = await this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        body: dto.body.trim(),
        editedAt: new Date(),
        modifiedByUserId: user.id,
      },
      include: messageInclude,
    });
    return toMessageDto(updated, viewer, parentName);
  }

  /**
   * Soft delete: the row keeps its place, so ordering and read markers stay
   * stable, while its text and photo are really erased.
   */
  async remove(user: ChatUser, messageId: number) {
    const { message, viewer, parentName } = await this.loadOwnSide(
      user,
      messageId,
    );
    if (message.deletedAt) return toMessageDto(message, viewer, parentName);

    const updated = await this.prisma.chatMessage.update({
      where: { id: messageId },
      data: {
        body: null,
        imagePath: null,
        deletedAt: new Date(),
        modifiedByUserId: user.id,
      },
      include: messageInclude,
    });
    if (message.imagePath) await this.photos.deleteChatPhoto(message.imagePath);
    return toMessageDto(updated, viewer, parentName);
  }

  /**
   * The message, if this user may change it: a parent their own messages in
   * their own thread; staff any staff message in a thread they can see.
   */
  private async loadOwnSide(user: ChatUser, messageId: number) {
    const message = await this.prisma.chatMessage.findUnique({
      where: { id: messageId },
      include: {
        ...messageInclude,
        conversation: {
          select: {
            parentId: true,
            parent: { select: { user: { select: { fullName: true } } } },
          },
        },
      },
    });
    if (!message) throw new NotFoundException('الرسالة غير موجودة');

    const parentId = message.conversation.parentId;
    const isStaff = user.role === 'ADMIN' || user.role === 'MANAGER';
    if (isStaff) {
      if (!message.fromStaff) throw new ForbiddenException(NO_ACCESS);
      await this.assertStaffScope(user, parentId);
    } else {
      if (message.fromStaff) throw new ForbiddenException(NO_ACCESS);
      if ((await this.ownParentId(user)) !== parentId) {
        throw new ForbiddenException(NO_ACCESS);
      }
    }
    const parentName = message.conversation.parent?.user.fullName ?? '';
    return { message, viewer: { isStaff }, parentName };
  }

  /** For the photo endpoint: the file of a message this user may see. */
  async photoPathFor(user: ChatUser, messageId: number): Promise<string> {
    const message = await this.prisma.chatMessage.findUnique({
      where: { id: messageId },
      select: {
        imagePath: true,
        deletedAt: true,
        conversation: { select: { parentId: true } },
      },
    });
    if (!message) throw new NotFoundException('الصورة غير موجودة');

    const parentId = message.conversation.parentId;
    if (user.role === 'ADMIN' || user.role === 'MANAGER') {
      await this.assertStaffScope(user, parentId);
    } else if ((await this.ownParentId(user)) !== parentId) {
      throw new ForbiddenException(NO_ACCESS);
    }
    if (message.deletedAt || !message.imagePath) {
      throw new NotFoundException('الصورة غير موجودة');
    }
    return message.imagePath;
  }
}
