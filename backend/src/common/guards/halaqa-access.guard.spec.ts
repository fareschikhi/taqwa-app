import {
  ExecutionContext,
  ForbiddenException,
  NotFoundException,
} from '@nestjs/common';
import { HalaqaAccessGuard } from './halaqa-access.guard';
import { HalaqaSource } from '../decorators/halaqa-source.decorator';

const contextFor = (request: Record<string, unknown>): ExecutionContext =>
  ({
    switchToHttp: () => ({ getRequest: () => request }),
    getHandler: () => undefined,
    getClass: () => undefined,
  }) as unknown as ExecutionContext;

const guardFor = (
  source: HalaqaSource | undefined,
  opts: {
    managerHalaqas?: { halaqaId: number }[];
    teacherHalaqas?: { id: number }[];
    ownStudent?: { halaqaId: number | null } | null;
    children?: { halaqaId: number | null }[];
    announcement?: { halaqaId: number } | null;
  } = {},
) => {
  const reflector = { getAllAndOverride: jest.fn().mockReturnValue(source) };
  const prisma = {
    managerHalaqa: {
      findMany: jest.fn().mockResolvedValue(opts.managerHalaqas ?? []),
    },
    halaqa: { findMany: jest.fn().mockResolvedValue(opts.teacherHalaqas ?? []) },
    student: {
      findUnique: jest.fn().mockResolvedValue(opts.ownStudent ?? null),
      findMany: jest.fn().mockResolvedValue(opts.children ?? []),
    },
    halaqaAnnouncement: {
      findUnique: jest.fn().mockResolvedValue(opts.announcement ?? null),
    },
  };
  return new HalaqaAccessGuard(reflector as never, prisma as never);
};

describe('HalaqaAccessGuard', () => {
  describe('resolving which halaqa is being reached', () => {
    it("reads params.id as the halaqa id under @HalaqaFrom('param')", async () => {
      const guard = guardFor('param', { managerHalaqas: [{ halaqaId: 4 }] });
      const request = {
        user: { role: 'MANAGER', id: 2, manager: { id: 5 } },
        params: { id: '4' },
      };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    it("reads body.halaqaId under @HalaqaFrom('body')", async () => {
      const guard = guardFor('body', { managerHalaqas: [{ halaqaId: 4 }] });
      const request = {
        user: { role: 'MANAGER', id: 2, manager: { id: 5 } },
        body: { halaqaId: 4, title: 'x', body: 'y' },
      };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    it("loads the announcement's halaqa under @HalaqaFrom('announcement')", async () => {
      const guard = guardFor('announcement', {
        managerHalaqas: [{ halaqaId: 4 }],
        announcement: { halaqaId: 4 },
      });
      const request = {
        user: { role: 'MANAGER', id: 2, manager: { id: 5 } },
        params: { id: '31' },
      };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    // 404, not 403: the row does not exist, which is not a permission
    // problem, and the service's error contract says الخبر غير موجود.
    it('throws NotFound when the announcement does not exist', async () => {
      const guard = guardFor('announcement', { announcement: null });
      const request = {
        user: { role: 'ADMIN', id: 1 },
        params: { id: '31' },
      };

      await expect(guard.canActivate(contextFor(request))).rejects.toBeInstanceOf(
        NotFoundException,
      );
    });

    // A route that forgets the decorator must not become a route that lets
    // everyone through.
    it('denies when no @HalaqaFrom is declared', async () => {
      const guard = guardFor(undefined);
      const request = { user: { role: 'ADMIN', id: 1 }, params: { id: '4' } };

      await expect(
        guard.canActivate(contextFor(request)),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('denies an unparsable id', async () => {
      const guard = guardFor('param');
      const request = { user: { role: 'ADMIN', id: 1 }, params: { id: 'abc' } };

      await expect(
        guard.canActivate(contextFor(request)),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });
  });

  describe('deciding who may reach it', () => {
    it('allows an ADMIN any halaqa', async () => {
      const guard = guardFor('param');
      const request = { user: { role: 'ADMIN', id: 1 }, params: { id: '99' } };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    // The whole point of the feature: a manager's own halaqas, not every
    // halaqa. Deliberately stricter than StudentOwnershipGuard, which waves
    // managers through.
    it('denies a MANAGER a halaqa they are not assigned to', async () => {
      const guard = guardFor('param', { managerHalaqas: [{ halaqaId: 4 }] });
      const request = {
        user: { role: 'MANAGER', id: 2, manager: { id: 5 } },
        params: { id: '7' },
      };

      await expect(
        guard.canActivate(contextFor(request)),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    // The message is the one the app already shows for an unauthorised
    // action — the Flutter repository puts `message` straight on screen, so
    // Nest's own English "Forbidden resource" would reach an Arabic user.
    it('denies in Arabic', async () => {
      const guard = guardFor('param', { managerHalaqas: [{ halaqaId: 4 }] });
      const request = {
        user: { role: 'MANAGER', id: 2, manager: { id: 5 } },
        params: { id: '7' },
      };

      await expect(guard.canActivate(contextFor(request))).rejects.toThrow(
        'غير مصرح لك بهذا الإجراء',
      );
    });

    it('allows a TEACHER her own halaqa and denies another', async () => {
      const request = (id: string) => ({
        user: { role: 'TEACHER', id: 3, teacher: { id: 8 } },
        params: { id },
      });

      await expect(
        guardFor('param', { teacherHalaqas: [{ id: 9 }] }).canActivate(
          contextFor(request('9')),
        ),
      ).resolves.toBe(true);
      await expect(
        guardFor('param', { teacherHalaqas: [{ id: 9 }] }).canActivate(
          contextFor(request('10')),
        ),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('allows a STUDENT his own halaqa', async () => {
      const guard = guardFor('param', { ownStudent: { halaqaId: 6 } });
      const request = { user: { role: 'STUDENT', id: 11 }, params: { id: '6' } };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    it("allows a PARENT a halaqa one of their children sits in", async () => {
      const guard = guardFor('param', { children: [{ halaqaId: 4 }, { halaqaId: 7 }] });
      const request = {
        user: { role: 'PARENT', id: 12, parent: { id: 3 } },
        params: { id: '7' },
      };

      await expect(guard.canActivate(contextFor(request))).resolves.toBe(true);
    });

    it("denies a PARENT a halaqa none of their children sits in", async () => {
      const guard = guardFor('param', { children: [{ halaqaId: 4 }] });
      const request = {
        user: { role: 'PARENT', id: 12, parent: { id: 3 } },
        params: { id: '7' },
      };

      await expect(
        guard.canActivate(contextFor(request)),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('denies an unrecognised role', async () => {
      const guard = guardFor('param');
      const request = { user: { role: 'SOMETHING_NEW', id: 2 }, params: { id: '4' } };

      await expect(
        guard.canActivate(contextFor(request)),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });

    it('denies when there is no user on the request', async () => {
      const guard = guardFor('param');

      await expect(
        guard.canActivate(contextFor({ params: { id: '4' } })),
      ).rejects.toBeInstanceOf(ForbiddenException);
    });
  });
});
