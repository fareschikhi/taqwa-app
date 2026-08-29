import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Keeps track of which devices a user is signed in on, so a notification has
 * somewhere to be pushed to. The rows carry no content — they are addresses.
 */
@Injectable()
export class DevicesService {
  constructor(private prisma: PrismaService) {}

  /**
   * Claims a device for the signed-in user.
   *
   * Keyed on the token rather than the user: FCM hands the same token back to
   * a reinstalled app, and a shared phone moves between accounts. Re-pointing
   * the row is what stops the previous user staying subscribed to a device
   * they no longer hold.
   */
  async register(userId: number, token: string, platform: string) {
    return this.prisma.deviceToken.upsert({
      where: { token },
      update: { userId, platform },
      create: { userId, token, platform },
    });
  }

  /**
   * Releases a device on sign-out. Scoped by the caller as well as the token,
   * so a token that leaked cannot be used to silence another user's phone.
   */
  async unregister(userId: number, token: string) {
    return this.prisma.deviceToken.deleteMany({ where: { token, userId } });
  }
}
