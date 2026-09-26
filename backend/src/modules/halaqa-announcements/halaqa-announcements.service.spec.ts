import {
  BadRequestException,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import {
  collapseBatches,
  HalaqaAnnouncementsService,
} from './halaqa-announcements.service';

const makePrisma = (opts: {
  managerHalaqas?: { halaqaId: number }[];
  halaqas?: { id: number }[];
  existing?: { id: number; batchId?: string | null } | null;
  rows?: unknown[];
} = {}) => ({
  managerHalaqa: {
    findMany: jest.fn().mockResolvedValue(opts.managerHalaqas ?? []),
  },
  halaqa: { findMany: jest.fn().mockResolvedValue(opts.halaqas ?? []) },
  student: {
    findUnique: jest.fn().mockResolvedValue(null),
    findMany: jest.fn().mockResolvedValue([]),
  },
  halaqaAnnouncement: {
    findMany: jest.fn().mockResolvedValue(opts.rows ?? []),
    findUnique: jest
      .fn()
      .mockResolvedValue(opts.existing === undefined ? { id: 31 } : opts.existing),
    create: jest
      .fn()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .mockImplementation(({ data }: any) => Promise.resolve({ id: 31, ...data })),
    createMany: jest.fn().mockResolvedValue({ count: 0 }),
    update: jest.fn().mockResolvedValue({ id: 31 }),
    updateMany: jest.fn().mockResolvedValue({ count: 0 }),
    delete: jest.fn().mockResolvedValue({ id: 31 }),
    deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
  },
});

const ADMIN = { role: 'ADMIN', id: 1 };
const MANAGER = { role: 'MANAGER', id: 2, manager: { id: 5 } };

const row = (id: number, halaqaId: number, batchId: string | null) => ({
  id,
  halaqaId,
  batchId,
  halaqa: { id: halaqaId, name: `حلقة ${halaqaId}` },
});

describe('HalaqaAnnouncementsService', () => {
  describe('findMine', () => {
    it('filters to the halaqas a manager is assigned to', async () => {
      const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }, { halaqaId: 7 }] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.findMine({ role: 'MANAGER', id: 2, manager: { id: 5 } });

      expect(prisma.halaqaAnnouncement.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { halaqaId: { in: [4, 7] } },
          orderBy: { createdAt: 'desc' },
        }),
      );
    });

    it('does not filter for an admin', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.findMine({ role: 'ADMIN', id: 1 });

      expect(prisma.halaqaAnnouncement.findMany).toHaveBeenCalledWith(
        expect.objectContaining({ where: {} }),
      );
    });

    // `in: []` would be a pointless round trip, and a bug that dropped the
    // filter entirely would hand this user everything.
    it('returns nothing without querying when the caller has no halaqas', async () => {
      const prisma = makePrisma({ managerHalaqas: [] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(
        service.findMine({ role: 'MANAGER', id: 2, manager: { id: 5 } }),
      ).resolves.toEqual([]);
      expect(prisma.halaqaAnnouncement.findMany).not.toHaveBeenCalled();
    });

    it('returns nothing for an unrecognised role', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(
        service.findMine({ role: 'SOMETHING_NEW', id: 2 }),
      ).resolves.toEqual([]);
      expect(prisma.halaqaAnnouncement.findMany).not.toHaveBeenCalled();
    });

    it('includes the halaqa name and the author name', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.findMine({ role: 'ADMIN', id: 1 });

      expect(prisma.halaqaAnnouncement.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          include: {
            halaqa: { select: { id: true, name: true } },
            author: { select: { id: true, fullName: true } },
          },
        }),
      );
    });
  });

  describe('collapseBatches', () => {
    it('folds one batch into its first row and keeps the feed order', () => {
      const items = collapseBatches([
        row(9, 4, 'b1'),
        row(8, 1, null),
        row(7, 7, 'b1'),
      ]);

      expect(items.map((i) => i.id)).toEqual([9, 8]);
      expect(items[0].halaqas.map((h) => h.id)).toEqual([4, 7]);
      expect(items[1].halaqas.map((h) => h.id)).toEqual([1]);
    });

    it('never merges news posted to a single halaqa', () => {
      expect(collapseBatches([row(2, 4, null), row(1, 4, null)])).toHaveLength(2);
    });
  });

  describe('createForAll', () => {
    const news = { title: 'عطلة', body: 'الحلقات معطلة غدا' };

    it("posts to every halaqa for an admin, under one batch", async () => {
      const prisma = makePrisma({ halaqas: [{ id: 1 }, { id: 2 }, { id: 3 }] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.createForAll(news, ADMIN);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = (prisma.halaqaAnnouncement.createMany as any).mock.calls[0][0];
      expect(data.map((d: { halaqaId: number }) => d.halaqaId)).toEqual([1, 2, 3]);
      expect(new Set(data.map((d: { batchId: string }) => d.batchId)).size).toBe(1);
      expect(data[0]).toEqual(
        expect.objectContaining({ authorId: 1, title: 'عطلة', body: 'الحلقات معطلة غدا' }),
      );
    });

    it('posts only to the halaqas a manager is assigned to', async () => {
      const prisma = makePrisma({ managerHalaqas: [{ halaqaId: 4 }, { halaqaId: 7 }] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.createForAll(news, MANAGER);

      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const { data } = (prisma.halaqaAnnouncement.createMany as any).mock.calls[0][0];
      expect(data.map((d: { halaqaId: number }) => d.halaqaId)).toEqual([4, 7]);
      expect(prisma.halaqa.findMany).not.toHaveBeenCalled();
    });

    it('refuses when the caller has no halaqas', async () => {
      const prisma = makePrisma({ managerHalaqas: [] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(service.createForAll(news, MANAGER)).rejects.toBeInstanceOf(
        BadRequestException,
      );
      expect(prisma.halaqaAnnouncement.createMany).not.toHaveBeenCalled();
    });
  });

  describe('batches', () => {
    const batched = { id: 31, batchId: 'b1' };

    it('edits every halaqa copy of an all-halaqas post', async () => {
      const prisma = makePrisma({ existing: batched, rows: [{ halaqaId: 4 }] });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.update(31, { title: 'x' }, ADMIN);

      expect(prisma.halaqaAnnouncement.updateMany).toHaveBeenCalledWith({
        where: { batchId: 'b1' },
        data: { title: 'x' },
      });
      expect(prisma.halaqaAnnouncement.update).not.toHaveBeenCalled();
    });

    it('deletes every halaqa copy of an all-halaqas post', async () => {
      const prisma = makePrisma({
        existing: batched,
        managerHalaqas: [{ halaqaId: 4 }],
        rows: [{ halaqaId: 4 }],
      });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.remove(31, MANAGER);

      expect(prisma.halaqaAnnouncement.deleteMany).toHaveBeenCalledWith({
        where: { batchId: 'b1' },
      });
    });

    // The guard only checked the row in the URL; the batch reaches further.
    it("stops a manager from touching an admin's post that reaches other halaqas", async () => {
      const prisma = makePrisma({
        existing: batched,
        managerHalaqas: [{ halaqaId: 4 }],
        rows: [{ halaqaId: 4 }, { halaqaId: 9 }],
      });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(service.update(31, { title: 'x' }, MANAGER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      await expect(service.remove(31, MANAGER)).rejects.toBeInstanceOf(
        ForbiddenException,
      );
      expect(prisma.halaqaAnnouncement.updateMany).not.toHaveBeenCalled();
      expect(prisma.halaqaAnnouncement.deleteMany).not.toHaveBeenCalled();
    });
  });

  describe('findByHalaqa', () => {
    it('reads one halaqa newest first', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.findByHalaqa(4);

      expect(prisma.halaqaAnnouncement.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { halaqaId: 4 },
          orderBy: { createdAt: 'desc' },
        }),
      );
    });
  });

  describe('create', () => {
    // The author is the authenticated user, never a body field — otherwise a
    // manager could post under the admin's name.
    it('stores the authenticated user as the author', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.create(
        { halaqaId: 4, title: 'غياب المعلم', body: 'الحلقة معطلة غدا' },
        17,
      );

      expect(prisma.halaqaAnnouncement.create).toHaveBeenCalledWith(
        expect.objectContaining({
          data: {
            halaqaId: 4,
            authorId: 17,
            title: 'غياب المعلم',
            body: 'الحلقة معطلة غدا',
          },
        }),
      );
    });
  });

  describe('update', () => {
    it('patches an existing announcement', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.update(31, { title: 'تغيير التوقيت' }, ADMIN);

      expect(prisma.halaqaAnnouncement.update).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { id: 31 },
          data: { title: 'تغيير التوقيت' },
        }),
      );
    });

    it('throws NotFound for a missing announcement', async () => {
      const prisma = makePrisma({ existing: null });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(service.update(31, { title: 'x' }, ADMIN)).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.halaqaAnnouncement.update).not.toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('deletes an existing announcement', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.remove(31, ADMIN);

      expect(prisma.halaqaAnnouncement.delete).toHaveBeenCalledWith({
        where: { id: 31 },
      });
    });

    it('throws NotFound for a missing announcement', async () => {
      const prisma = makePrisma({ existing: null });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(service.remove(31, ADMIN)).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.halaqaAnnouncement.delete).not.toHaveBeenCalled();
    });
  });
});
