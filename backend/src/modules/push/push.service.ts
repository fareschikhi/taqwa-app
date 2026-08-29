import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import { BatchResponse, getMessaging } from 'firebase-admin/messaging';
import { PrismaService } from '../../prisma/prisma.service';
import { requireEnv } from '../../common/config/env';

/**
 * FCM's three permanent verdicts on a registration token. Anything else — a
 * rate limit, an outage — says nothing about the device and passes.
 */
const DEAD_TOKEN_CODES = [
  'messaging/invalid-registration-token',
  'messaging/registration-token-not-registered',
  'messaging/installation-id-not-registered',
];

/** Everything the Admin SDK needs to authenticate as this project. */
const FIREBASE_KEYS = [
  'FIREBASE_PROJECT_ID',
  'FIREBASE_CLIENT_EMAIL',
  'FIREBASE_PRIVATE_KEY',
];

/**
 * Delivers a notification to the devices a user is signed in on.
 *
 * The stored notification row is the record; this is best-effort delivery of
 * it. A parent who has never opened the app, or who refused the permission,
 * simply has no devices here and reads the same rows in the app instead.
 */
@Injectable()
export class PushService implements OnModuleInit {
  private readonly logger = new Logger(PushService.name);

  constructor(private prisma: PrismaService) {}

  private enabled = false;

  /**
   * Push is optional, and its absence is not a misconfiguration: the app was
   * built and deployed before any Firebase project existed, and every other
   * feature works without it. So none of the three variables means push is
   * simply off, and the API starts.
   *
   * Some of them is a different thing — a mistake being made — and fails at
   * boot the way UploadsService does, rather than surfacing when a parent
   * fails to hear about an absence.
   */
  onModuleInit() {
    const provided = FIREBASE_KEYS.filter((key) => process.env[key]);
    if (!provided.length) {
      this.logger.warn(
        'Firebase is not configured; push delivery is off. Notifications are ' +
          'still written and readable in the app.',
      );
      return;
    }

    const credential = {
      projectId: requireEnv('FIREBASE_PROJECT_ID'),
      clientEmail: requireEnv('FIREBASE_CLIENT_EMAIL'),
      // A host that stores secrets as single-line values keeps the key's
      // newlines escaped; the SDK needs the real ones back.
      privateKey: requireEnv('FIREBASE_PRIVATE_KEY').replace(/\\n/g, '\n'),
    };

    // Nest instantiates this once, but a test importing the module twice
    // would otherwise throw on a duplicate default app.
    if (!getApps().length) initializeApp({ credential: cert(credential) });
    this.enabled = true;
  }

  async sendToUser(userId: number, title: string, body: string) {
    if (!this.enabled) return;

    const devices = await this.prisma.deviceToken.findMany({
      where: { userId },
      select: { token: true },
    });
    if (!devices.length) return;

    const result = await getMessaging().sendEach(
      devices.map(({ token }) => ({
        token,
        notification: { title, body },
        // Read by the app's tap handler to open the notifications tab.
        data: { route: 'notifications' },
        android: { priority: 'high' as const },
      })),
    );

    await this.pruneDeadTokens(devices, result);
  }

  /**
   * Drops tokens FCM has declared permanently gone — the app was uninstalled,
   * or its data cleared. FCM only reports this on a send, so left in place
   * they accumulate and every later send pays for them.
   */
  private async pruneDeadTokens(
    devices: Array<{ token: string }>,
    result: BatchResponse,
  ) {
    const dead = result.responses
      .map((response, i) => ({ response, token: devices[i].token }))
      .filter(
        ({ response }) =>
          !response.success &&
          DEAD_TOKEN_CODES.includes(response.error?.code ?? ''),
      )
      .map(({ token }) => token);

    if (!dead.length) return;
    await this.prisma.deviceToken.deleteMany({
      where: { token: { in: dead } },
    });
    this.logger.log(`Pruned ${dead.length} dead device token(s)`);
  }
}
