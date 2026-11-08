import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { ChatService } from './chat.service';
import * as access from './chat-access';

jest.mock('./chat-access');
const mocked = access as jest.Mocked<typeof access>;

const at = new Date('2026-11-02T10:00:00Z');

const row = (over: Record<string, unknown> = {}) => ({
  id: 1,
  conversationId: 11,
  senderUserId: 30,
  fromStaff: false,
  body: 'نص',
  imagePath: null,
  editedAt: null,
  deletedAt: null,
  modifiedByUserId: null,
  createdAt: at,
  updatedAt: at,
  sender: { fullName: 'محمد بن علي' },
  ...over,
});

const parentRecord = (over: Record<string, unknown> = {}) => ({
  id: 9,
  user: { id: 30, fullName: 'محمد بن علي', isActive: true },
  chatConversation: { id: 11 },
  ...over,
});

function makePrisma() {
  const prisma: any = {
    parent: {
      findUnique: jest.fn().mockResolvedValue(parentRecord()),
      findMany: jest.fn().mockResolvedValue([]),
    },
    chatConversation: {
      upsert: jest.fn().mockResolvedValue({ id: 11 }),
      findUnique: jest.fn().mockResolvedValue({ id: 11 }),
      findMany: jest.fn().mockResolvedValue([]),
    },
    chatMessage: {
      create: jest
        .fn()
        .mockImplementation(({ data }) =>
          Promise.resolve(row({ id: 99, ...data })),
        ),
      findMany: jest.fn().mockResolvedValue([]),
      findUnique: jest.fn(),
      findFirst: jest.fn().mockResolvedValue({ id: 99 }),
      update: jest
        .fn()
        .mockImplementation(({ data }) => Promise.resolve(row(data))),
      count: jest.fn().mockResolvedValue(0),
      groupBy: jest.fn().mockResolvedValue([]),
    },
    chatRead: {
      upsert: jest.fn(),
      findUnique: jest.fn().mockResolvedValue(null),
    },
  };
  prisma.$transaction = jest.fn((fn: (tx: unknown) => unknown) => fn(prisma));
  return prisma;
}

const notifier = { messageSent: jest.fn().mockResolvedValue(undefined) };
const deleter = { deleteChatPhoto: jest.fn().mockResolvedValue(undefined) };

const parentUser = { role: 'PARENT', id: 30, parent: { id: 9 } };
const admin = { role: 'ADMIN', id: 1 };

function makeService(prisma = makePrisma()) {
  return {
    prisma,
    service: new ChatService(prisma, notifier as any, deleter as any),
  };
}

beforeEach(() => {
  jest.clearAllMocks();
  mocked.chatParentIdForParentUser.mockResolvedValue(9);
  mocked.canStaffSeeParent.mockResolvedValue(true);
  mocked.chatParentWhere.mockResolvedValue({ students: { some: {} } });
  mocked.chatScope.mockResolvedValue({
    where: { students: { some: {} } },
    covers: () => true,
  });
});

describe('ChatService access', () => {
  it('refuses a parent with no linked child', async () => {
    mocked.chatParentIdForParentUser.mockResolvedValue(null);
    const { service } = makeService();

    await expect(service.parentPage(parentUser, {})).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('refuses a staff thread once the parent is out of scope', async () => {
    mocked.canStaffSeeParent.mockResolvedValue(false);
    const { service } = makeService();

    await expect(service.staffPage(admin, 9, {})).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});

describe('ChatService.send', () => {
  it('creates the conversation on the first message and bumps lastMessageAt', async () => {
    const { service, prisma } = makeService();

    await service.parentSend(parentUser, { body: '  مرحبا  ' });

    expect(prisma.chatConversation.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { parentId: 9 },
        create: expect.objectContaining({ parentId: 9 }),
        update: { lastMessageAt: expect.any(Date) },
      }),
    );
    expect(prisma.chatMessage.create.mock.calls[0][0].data).toMatchObject({
      conversationId: 11,
      senderUserId: 30,
      fromStaff: false,
      body: 'مرحبا',
    });
  });

  it('moves the sender read marker to their own message', async () => {
    const { service, prisma } = makeService();

    await service.staffSend(admin, 9, { body: 'أهلاً' });

    expect(prisma.chatRead.upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        where: { conversationId_userId: { conversationId: 11, userId: 1 } },
        create: { conversationId: 11, userId: 1, lastReadMessageId: 99 },
      }),
    );
  });

  it('rejects a message with no text and no photo', async () => {
    const { service } = makeService();

    await expect(
      service.parentSend(parentUser, { body: '   ' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses to write to a deactivated parent', async () => {
    const prisma = makePrisma();
    prisma.parent.findUnique.mockResolvedValue(
      parentRecord({ user: { id: 30, fullName: 'x', isActive: false } }),
    );
    const { service } = makeService(prisma);

    await expect(
      service.staffSend(admin, 9, { body: 'أهلاً' }),
      // Not 403: the staff member still has the thread, and the app must keep
      // them in it (403 means "you lost access" there).
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('hands the new message to the notifier', async () => {
    const { service } = makeService();

    await service.staffSend(admin, 9, { body: 'أهلاً' });

    expect(notifier.messageSent).toHaveBeenCalledWith(
      expect.objectContaining({
        parentId: 9,
        parentUserId: 30,
        fromStaff: true,
        text: 'أهلاً',
      }),
    );
  });
});

describe('ChatService pages', () => {
  it('returns new, edited and deleted messages since, with an overlap', async () => {
    const { service, prisma } = makeService();
    const since = '2026-11-02T09:00:00.000Z';

    await service.staffPage(admin, 9, { since });

    expect(prisma.chatMessage.findMany.mock.calls[0][0].where).toEqual({
      conversationId: 11,
      // Looks back past since: a row stamped before the previous poll's
      // serverTime but committed after it must not be skipped for good.
      updatedAt: { gte: new Date(new Date(since).getTime() - 5000) },
    });
  });

  it('pages back with before and reports whether more remain', async () => {
    const prisma = makePrisma();
    prisma.chatMessage.findMany.mockResolvedValue(
      Array.from({ length: 31 }, (_, i) => row({ id: 100 - i })),
    );
    const { service } = makeService(prisma);

    const page = await service.staffPage(admin, 9, { before: 101 });

    expect(prisma.chatMessage.findMany.mock.calls[0][0]).toMatchObject({
      where: { conversationId: 11, id: { lt: 101 } },
      orderBy: { id: 'desc' },
      take: 31,
    });
    expect(page.hasMore).toBe(true);
    expect(page.messages).toHaveLength(30);
    // Oldest first, so the app can append in order.
    expect(page.messages[0].id).toBeLessThan(page.messages[29].id);
  });

  it('returns an empty page before any message exists', async () => {
    const prisma = makePrisma();
    prisma.parent.findUnique.mockResolvedValue(
      parentRecord({ chatConversation: null }),
    );
    const { service } = makeService(prisma);

    const page = await service.parentPage(parentUser, {});

    expect(page.messages).toEqual([]);
    expect(prisma.chatMessage.findMany).not.toHaveBeenCalled();
  });
});

describe('ChatService unread', () => {
  it('counts for staff only parent messages after their own marker', async () => {
    const prisma = makePrisma();
    prisma.chatConversation.findMany.mockResolvedValue([
      { id: 11, reads: [{ lastReadMessageId: 5 }] },
      { id: 12, reads: [] },
    ]);
    prisma.chatMessage.groupBy.mockResolvedValue([
      { conversationId: 11, _count: { _all: 2 } },
      { conversationId: 12, _count: { _all: 3 } },
    ]);
    const { service } = makeService(prisma);

    await expect(service.staffUnread(admin)).resolves.toEqual({ count: 5 });
    expect(prisma.chatMessage.groupBy.mock.calls[0][0].where).toEqual({
      fromStaff: false,
      deletedAt: null,
      OR: [
        { conversationId: 11, id: { gt: 5 } },
        { conversationId: 12, id: { gt: 0 } },
      ],
    });
  });

  it('counts for the parent only staff messages after their marker', async () => {
    const prisma = makePrisma();
    prisma.chatRead.findUnique.mockResolvedValue({ lastReadMessageId: 40 });
    prisma.chatMessage.count.mockResolvedValue(2);
    const { service } = makeService(prisma);

    await expect(service.parentUnread(parentUser)).resolves.toEqual({
      count: 2,
    });
    expect(prisma.chatMessage.count).toHaveBeenCalledWith({
      where: {
        conversationId: 11,
        fromStaff: true,
        deletedAt: null,
        id: { gt: 40 },
      },
    });
  });
});

describe('ChatService edit and delete', () => {
  const withMessage = (message: ReturnType<typeof row>) => {
    const prisma = makePrisma();
    prisma.chatMessage.findUnique.mockResolvedValue({
      ...message,
      conversation: { parentId: 9 },
    });
    return makeService(prisma);
  };

  it('does not let a parent edit a staff message', async () => {
    const { service } = withMessage(row({ fromStaff: true, senderUserId: 55 }));

    await expect(
      service.edit(parentUser, 1, { body: 'x' }),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('lets any staff member edit a colleague message', async () => {
    const { service, prisma } = withMessage(
      row({ fromStaff: true, senderUserId: 55 }),
    );

    await service.edit(admin, 1, { body: 'مصحح' });

    expect(prisma.chatMessage.update.mock.calls[0][0].data).toMatchObject({
      body: 'مصحح',
      editedAt: expect.any(Date),
      modifiedByUserId: 1,
    });
  });

  it('does not let staff delete a parent message', async () => {
    const { service } = withMessage(row({ fromStaff: false }));

    await expect(service.remove(admin, 1)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('does not let a parent touch another parent thread', async () => {
    mocked.chatParentIdForParentUser.mockResolvedValue(4);
    const { service } = withMessage(row({ fromStaff: false }));

    await expect(service.remove(parentUser, 1)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('wipes text and photo on delete and removes the file', async () => {
    const { service, prisma } = withMessage(
      row({ fromStaff: false, imagePath: '.chat/a.jpg' }),
    );

    await service.remove(parentUser, 1);

    expect(prisma.chatMessage.update.mock.calls[0][0].data).toMatchObject({
      body: null,
      imagePath: null,
      deletedAt: expect.any(Date),
      modifiedByUserId: 30,
    });
    expect(deleter.deleteChatPhoto).toHaveBeenCalledWith('.chat/a.jpg');
  });

  it('refuses to edit a photo with no caption', async () => {
    const { service } = withMessage(
      row({ fromStaff: false, body: null, imagePath: '.chat/a.jpg' }),
    );

    await expect(
      service.edit(parentUser, 1, { body: 'x' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('refuses to edit a deleted message', async () => {
    const { service } = withMessage(row({ deletedAt: at, body: null }));

    await expect(
      service.edit(parentUser, 1, { body: 'x' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });
});

describe('ChatService inbox', () => {
  it('never shows the text of a deleted last message', async () => {
    const prisma = makePrisma();
    prisma.parent.findMany.mockResolvedValue([
      {
        id: 9,
        user: { fullName: 'محمد بن علي', avatar: null },
        students: [],
        chatConversation: {
          id: 11,
          messages: [row({ body: null, deletedAt: at })],
          reads: [],
        },
      },
    ]);
    const { service } = makeService(prisma);

    const [item] = await service.inbox(admin, undefined);

    expect(item.lastMessage?.preview).toBe('تم حذف هذه الرسالة');
  });

  it("marks only the children inside the viewer's scope", async () => {
    // A manager of halaqa 4 whose parent also has a child in halaqa 7.
    mocked.chatScope.mockResolvedValue({
      where: { students: { some: {} } },
      covers: (id) => id === 4,
    });
    const prisma = makePrisma();
    prisma.parent.findMany.mockResolvedValue([
      {
        id: 9,
        user: { fullName: 'محمد بن علي', avatar: null },
        students: [
          {
            id: 1,
            user: { fullName: 'يوسف' },
            halaqa: { id: 4, name: 'الفرقان' },
          },
          {
            id: 2,
            user: { fullName: 'سارة' },
            halaqa: { id: 7, name: 'النور' },
          },
          { id: 3, user: { fullName: 'علي' }, halaqa: null },
        ],
        chatConversation: null,
      },
    ]);
    const { service } = makeService(prisma);

    const [item] = await service.pickableParents(admin, undefined);

    expect(item.children).toEqual([
      {
        id: 1,
        fullName: 'يوسف',
        halaqaId: 4,
        halaqaName: 'الفرقان',
        inScope: true,
      },
      {
        id: 2,
        fullName: 'سارة',
        halaqaId: 7,
        halaqaName: 'النور',
        inScope: false,
      },
      {
        id: 3,
        fullName: 'علي',
        halaqaId: null,
        halaqaName: null,
        inScope: false,
      },
    ]);
  });

  it("finds parents by their child's halaqa name too", async () => {
    const prisma = makePrisma();
    prisma.parent.findMany.mockResolvedValue([]);
    const { service } = makeService(prisma);

    await service.inbox(admin, ' الفرقان ');

    const where = prisma.parent.findMany.mock.calls[0][0].where;
    expect(where.AND[1].OR).toContainEqual({
      students: { some: { halaqa: { name: { contains: 'الفرقان' } } } },
    });
  });

  it('refuses a user with no chat scope', async () => {
    mocked.chatScope.mockResolvedValue(null);
    const { service } = makeService();

    await expect(service.inbox(admin, undefined)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });
});

describe('ChatService photos', () => {
  const withPhoto = (over: Record<string, unknown> = {}) => {
    const prisma = makePrisma();
    prisma.chatMessage.findUnique.mockResolvedValue({
      imagePath: '.chat/a.jpg',
      deletedAt: null,
      conversation: { parentId: 9 },
      ...over,
    });
    return makeService(prisma);
  };

  it('gives the photo path to a staff member in scope', async () => {
    const { service } = withPhoto();

    await expect(service.photoPathFor(admin, 1)).resolves.toBe('.chat/a.jpg');
  });

  it('refuses the photo to a staff member out of scope', async () => {
    mocked.canStaffSeeParent.mockResolvedValue(false);
    const { service } = withPhoto();

    await expect(service.photoPathFor(admin, 1)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('refuses the photo to another parent', async () => {
    mocked.chatParentIdForParentUser.mockResolvedValue(4);
    const { service } = withPhoto();

    await expect(service.photoPathFor(parentUser, 1)).rejects.toBeInstanceOf(
      ForbiddenException,
    );
  });

  it('has no photo for a deleted message', async () => {
    const { service } = withPhoto({ deletedAt: at, imagePath: null });

    await expect(service.photoPathFor(admin, 1)).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
