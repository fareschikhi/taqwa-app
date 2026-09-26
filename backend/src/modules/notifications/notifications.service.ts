import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { CreateNotificationDto, UpdateNotificationDto } from './dto/notification.dto';
import { PushService } from '../push/push.service';

@Injectable()
export class NotificationsService {
  constructor(
    private prisma: PrismaService,
    private push: PushService,
  ) {}

  /**
   * Writes the notification and delivers it.
   *
   * Every producer reaches a parent through this one method, so delivery
   * belongs here rather than in each of them: attendance and student notes
   * both push without either knowing that push exists, and so does whatever
   * announces itself next.
   */
  async create(dto: CreateNotificationDto) {
    const notification = await this.prisma.notification.create({ data: dto });

    // The row is the record and the push is best-effort delivery of it. A
    // parent whose phone could not be reached still finds it in the app, so a
    // failed send must not cost the notification — the same rule the
    // producers already apply to the record that prompted them.
    try {
      await this.push.sendToUser(dto.userId, dto.title, dto.body);
    } catch (_) {
      // Deliberately silent — see above.
    }

    return notification;
  }

  /**
   * With a studentId, narrows a parent's list to that child: the rows about
   * him, plus the ones about no child in particular, which belong in every
   * child's list rather than none.
   */
  private scope(userId: number, studentId?: number) {
    return studentId === undefined
      ? { userId }
      : { userId, OR: [{ studentId }, { studentId: null }] };
  }

  async findAllForUser(userId: number, studentId?: number) {
    return this.prisma.notification.findMany({
      where: this.scope(userId, studentId),
      orderBy: { createdAt: 'desc' },
    });
  }

  async getUnreadCount(userId: number, studentId?: number) {
    const count = await this.prisma.notification.count({
      where: { ...this.scope(userId, studentId), isRead: false },
    });
    return { count };
  }

  async markAsRead(id: number, userId: number) {
    const existing = await this.prisma.notification.findFirst({
      where: { id, userId },
    });
    if (!existing) throw new NotFoundException('الإشعار غير موجود');

    return this.prisma.notification.update({
      where: { id },
      data: { isRead: true },
    });
  }

  async markAllAsRead(userId: number, studentId?: number) {
    return this.prisma.notification.updateMany({
      where: { ...this.scope(userId, studentId), isRead: false },
      data: { isRead: true },
    });
  }
}
