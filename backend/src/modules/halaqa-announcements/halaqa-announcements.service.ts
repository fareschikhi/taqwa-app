import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ALL_HALAQAS,
  halaqaIdsFor,
  ScopedUser,
} from '../../common/guards/halaqa-scope';
import {
  CreateHalaqaAnnouncementDto,
  UpdateHalaqaAnnouncementDto,
} from './dto/halaqa-announcement.dto';

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

    return this.prisma.halaqaAnnouncement.findMany({
      where: scope === ALL_HALAQAS ? {} : { halaqaId: { in: scope } },
      include: this.include,
      orderBy: { createdAt: 'desc' },
    });
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

  async update(id: number, dto: UpdateHalaqaAnnouncementDto) {
    const existing = await this.prisma.halaqaAnnouncement.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('الخبر غير موجود');

    return this.prisma.halaqaAnnouncement.update({
      where: { id },
      data: dto,
      include: this.include,
    });
  }

  async remove(id: number) {
    const existing = await this.prisma.halaqaAnnouncement.findUnique({
      where: { id },
    });
    if (!existing) throw new NotFoundException('الخبر غير موجود');

    return this.prisma.halaqaAnnouncement.delete({ where: { id } });
  }
}
