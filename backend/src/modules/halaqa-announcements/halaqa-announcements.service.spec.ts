import { NotFoundException } from '@nestjs/common';
import { HalaqaAnnouncementsService } from './halaqa-announcements.service';

const makePrisma = (opts: {
  managerHalaqas?: { halaqaId: number }[];
  existing?: { id: number } | null;
} = {}) => ({
  managerHalaqa: {
    findMany: jest.fn().mockResolvedValue(opts.managerHalaqas ?? []),
  },
  halaqa: { findMany: jest.fn().mockResolvedValue([]) },
  student: {
    findUnique: jest.fn().mockResolvedValue(null),
    findMany: jest.fn().mockResolvedValue([]),
  },
  halaqaAnnouncement: {
    findMany: jest.fn().mockResolvedValue([]),
    findUnique: jest
      .fn()
      .mockResolvedValue(opts.existing === undefined ? { id: 31 } : opts.existing),
    create: jest
      .fn()
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      .mockImplementation(({ data }: any) => Promise.resolve({ id: 31, ...data })),
    update: jest.fn().mockResolvedValue({ id: 31 }),
    delete: jest.fn().mockResolvedValue({ id: 31 }),
  },
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

      await service.update(31, { title: 'تغيير التوقيت' });

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

      await expect(service.update(31, { title: 'x' })).rejects.toBeInstanceOf(
        NotFoundException,
      );
      expect(prisma.halaqaAnnouncement.update).not.toHaveBeenCalled();
    });
  });

  describe('remove', () => {
    it('deletes an existing announcement', async () => {
      const prisma = makePrisma();
      const service = new HalaqaAnnouncementsService(prisma as never);

      await service.remove(31);

      expect(prisma.halaqaAnnouncement.delete).toHaveBeenCalledWith({
        where: { id: 31 },
      });
    });

    it('throws NotFound for a missing announcement', async () => {
      const prisma = makePrisma({ existing: null });
      const service = new HalaqaAnnouncementsService(prisma as never);

      await expect(service.remove(31)).rejects.toBeInstanceOf(NotFoundException);
      expect(prisma.halaqaAnnouncement.delete).not.toHaveBeenCalled();
    });
  });
});
