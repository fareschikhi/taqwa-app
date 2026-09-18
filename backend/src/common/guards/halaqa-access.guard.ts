import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { PrismaService } from '../../prisma/prisma.service';
import {
  HALAQA_SOURCE_KEY,
  HalaqaSource,
} from '../decorators/halaqa-source.decorator';
import { ALL_HALAQAS, halaqaIdsFor } from './halaqa-scope';

/**
 * Restricts a halaqa-scoped route to users tied to that halaqa.
 *
 * Reads the same rule as the `/mine` feed, via [halaqaIdsFor], so the two
 * directions of "who sees which halaqa" cannot drift apart.
 *
 * Unlike StudentOwnershipGuard this does NOT wave MANAGER through: a
 * manager's assignment is the feature's whole boundary, so it is checked on
 * reads and writes alike. Writes are additionally narrowed by `@Roles`.
 *
 * Denials throw rather than returning false, the way ManagerPermissionGuard
 * does: returning false lets Nest raise its own English "Forbidden resource",
 * and the app puts a rejection's `message` straight in front of the user.
 *
 * Guards run before pipes, so this guard resolves and rejects a malformed
 * halaqa id itself, before the DTO's own `@IsInt()` ever runs: a POST with a
 * missing or non-numeric `halaqaId` surfaces here as a denial rather than as
 * a validation error. That is deliberate — it still fails closed — but it
 * means the DTO's `halaqaId` validation is not reachable through this route
 * in practice.
 */
@Injectable()
export class HalaqaAccessGuard implements CanActivate {
  constructor(
    private reflector: Reflector,
    private prisma: PrismaService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const source = this.reflector.getAllAndOverride<HalaqaSource>(
      HALAQA_SOURCE_KEY,
      [context.getHandler(), context.getClass()],
    );
    // Fails closed: a route that forgot to declare its source is not a route
    // that admits everyone.
    if (!source) throw new ForbiddenException('غير مصرح لك بهذا الإجراء');

    const request = context.switchToHttp().getRequest();
    const halaqaId = await this.resolveHalaqaId(source, request);
    if (halaqaId === null) {
      throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
    }

    const scope = await halaqaIdsFor(this.prisma, request.user);
    if (scope === ALL_HALAQAS || scope.includes(halaqaId)) return true;

    throw new ForbiddenException('غير مصرح لك بهذا الإجراء');
  }

  private async resolveHalaqaId(
    source: HalaqaSource,
    request: {
      params?: Record<string, string>;
      body?: Record<string, unknown>;
    },
  ): Promise<number | null> {
    if (source === 'body') return asId(request.body?.halaqaId);

    const paramId = asId(request.params?.id);
    if (paramId === null) return null;
    if (source === 'param') return paramId;

    const announcement = await this.prisma.halaqaAnnouncement.findUnique({
      where: { id: paramId },
      select: { halaqaId: true },
    });
    // A missing row is a 404, not a permission problem, and the service's
    // error contract already words it this way.
    if (!announcement) throw new NotFoundException('الخبر غير موجود');
    return announcement.halaqaId;
  }
}

const asId = (raw: unknown): number | null => {
  const id = Number(raw);
  return Number.isInteger(id) && id > 0 ? id : null;
};
