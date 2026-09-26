import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ALL_HALAQAS,
  halaqaIdsFor,
  ScopedUser,
} from '../../common/guards/halaqa-scope';
import {
  CreateAllHalaqasAnnouncementDto,
  CreateHalaqaAnnouncementDto,
  UpdateHalaqaAnnouncementDto,
} from './dto/halaqa-announcement.dto';

type HalaqaRef = { id: number; name: string };

/**
 * Folds the rows of each "all halaqas" batch into the first of them, and
 * gives every item the list of halaqas it went to. Order is kept, so a feed
 * that arrived newest first stays newest first.
 */
export function collapseBatches<
  T extends { batchId: string | null; halaqa: HalaqaRef },
>(rows: T[]): (T & { halaqas: HalaqaRef[] })[] {
  const items: (T & { halaqas: HalaqaRef[] })[] = [];
  const byBatch = new Map<string, T & { halaqas: HalaqaRef[] }>();

  for (const row of rows) {
    const batched = row.batchId ? byBatch.get(row.batchId) : undefined;
    if (batched) {
      batched.halaqas.push(row.halaqa);
      continue;
    }
    const item = { ...row, halaqas: [row.halaqa] };
    items.push(item);
    if (row.batchId) byBatch.set(row.batchId, item);
  }
  return items;
}

@Injectable()
export class HalaqaAnnouncementsService {
  constructor(private prisma: PrismaService) {}

  private readonly include = {
    halaqa: { select: { id: true, name: true } },
    // The author is a User, so the name is on the row itself — unlike
    // StudentNote's teacher, which has to reach through to its user.
    author: { select: { id: true, fullName: true } },
  };

  /**
   * The caller's feed: every announcement on every halaqa they are tied to,
   * newest first. The scope comes from the shared rule the access guard also
   * reads, so a role handled in one is handled in both.
   */
  async findMine(user: ScopedUser) {
    const scope = await halaqaIdsFor(this.prisma, user);

    // An empty scope is not `in: []` — it is "nothing to ask for". Returning
    // early also means a future bug that dropped the filter cannot silently
    // turn this into "everything".
    if (scope !== ALL_HALAQAS && scope.length === 0) return [];

    const rows = await this.prisma.halaqaAnnouncement.findMany({
      where: scope === ALL_HALAQAS ? {} : { halaqaId: { in: scope } },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
    // An "all halaqas" post is one piece of news, not one per circle: a
    // manager, an admin or a parent with children in two halaqas would
    // otherwise see it repeated.
    return collapseBatches(rows);
  }

  /** One halaqa's history. Access is settled by HalaqaAccessGuard. */
  async findByHalaqa(halaqaId: number) {
    return this.prisma.halaqaAnnouncement.findMany({
      where: { halaqaId },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
  }

  /** `authorId` comes from the token, never from the body. */
  async create(dto: CreateHalaqaAnnouncementDto, authorId: number) {
    return this.prisma.halaqaAnnouncement.create({
      data: {
        halaqaId: dto.halaqaId,
        authorId,
        title: dto.title,
        body: dto.body,
      },
      include: this.include,
    });
  }

  /**
   * One announcement on every halaqa in the caller's scope — all of them for
   * an admin, the assigned ones for a manager — sharing one batch id.
   *
   * No access guard runs on this route: there is no single halaqa to check,
   * and the halaqa list comes from the same scope rule the guard reads, so
   * nothing outside the caller's reach can be named.
   */
  async createForAll(
    dto: CreateAllHalaqasAnnouncementDto,
    user: ScopedUser & { id: number },
  ) {
    const scope = await halaqaIdsFor(this.prisma, user);
    const halaqaIds =
      scope === ALL_HALAQAS
        ? (
            await this.prisma.halaqa.findMany({
              select: { id: true },
              orderBy: { id: 'asc' },
            })
          ).map((h) => h.id)
        : scope;
    if (halaqaIds.length === 0) {
      throw new BadRequestException('لا توجد حلقات لنشر الخبر فيها');
    }

    const batchId = randomUUID();
    // One statement, so a failure leaves no halaqa with half the batch.
    await this.prisma.halaqaAnnouncement.createMany({
      data: halaqaIds.map((halaqaId) => ({
        halaqaId,
        authorId: user.id,
        title: dto.title,
        body: dto.body,
        batchId,
      })),
    });

    const rows = await this.prisma.halaqaAnnouncement.findMany({
      where: { batchId },
      include: this.include,
      orderBy: { halaqaId: 'asc' },
    });
    return collapseBatches(rows)[0];
  }

  /**
   * Edits the announcement — and, for an "all halaqas" post, every halaqa's
   * copy of it, since the feed shows them as one.
   */
  async update(id: number, dto: UpdateHalaqaAnnouncementDto, user: ScopedUser) {
    const existing = await this.prisma.halaqaAnnouncement.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('الخبر غير موجود');

    if (existing.batchId) {
      await this.assertBatchInScope(existing.batchId, user);
      await this.prisma.halaqaAnnouncement.updateMany({
        where: { batchId: existing.batchId },
        data: dto,
      });
      return this.prisma.halaqaAnnouncement.findUnique({
        where: { id },
        include: this.include,
      });
    }

    return this.prisma.halaqaAnnouncement.update({
      where: { id },
      data: dto,
      include: this.include,
    });
  }

  /** Deletes the announcement, or the whole batch it belongs to. */
  async remove(id: number, user: ScopedUser) {
    const existing = await this.prisma.halaqaAnnouncement.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('الخبر غير موجود');

    if (existing.batchId) {
      await this.assertBatchInScope(existing.batchId, user);
      return this.prisma.halaqaAnnouncement.deleteMany({
        where: { batchId: existing.batchId },
      });
    }

    return this.prisma.halaqaAnnouncement.delete({ where: { id } });
  }

  /**
   * HalaqaAccessGuard only saw the one row in the URL. A batch reaches every
   * halaqa it was posted to, so the caller must reach all of them: a manager
   * cannot rewrite or erase what an admin told halaqas outside their charge.
   */
  private async assertBatchInScope(batchId: string, user: ScopedUser) {
    const scope = await halaqaIdsFor(this.prisma, user);
    if (scope === ALL_HALAQAS) return;

    const rows = await this.prisma.halaqaAnnouncement.findMany({
      where: { batchId },
      select: { halaqaId: true },
    });
    if (rows.some((r) => !scope.includes(r.halaqaId))) {
      throw new ForbiddenException(
        'هذا الخبر منشور في حلقات خارج صلاحياتك',
      );
    }
  }
}
