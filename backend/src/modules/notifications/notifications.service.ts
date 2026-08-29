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

  async findAllForUser(userId: number) {
    return this.prisma.notification.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async getUnreadCount(userId: number) {
    const count = await this.prisma.notification.count({
      where: { userId, isRead: false },
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

  async markAllAsRead(userId: number) {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
  }
}
