// The Admin SDK is the boundary being tested against, so it is stubbed at the
// module edge. `getMessaging` closes over one `sendEach` created in the
// factory, which keeps the same mock reachable from every call.
jest.mock('firebase-admin/app', () => ({
  getApps: jest.fn(() => [{}]),
  initializeApp: jest.fn(),
  cert: jest.fn(),
}));
jest.mock('firebase-admin/messaging', () => {
  const sendEach = jest.fn();
  return { getMessaging: jest.fn(() => ({ sendEach })) };
});

import { getMessaging } from 'firebase-admin/messaging';
import { PushService } from './push.service';

const sendEach = () => (getMessaging() as any).sendEach as jest.Mock;

/** A send result in the shape `sendEach` returns, one response per token. */
const batch = (...responses: Array<{ success: boolean; code?: string }>) => ({
  successCount: responses.filter((r) => r.success).length,
  failureCount: responses.filter((r) => !r.success).length,
  responses: responses.map((r) =>
    r.success
      ? { success: true, messageId: 'm1' }
      : { success: false, error: { code: r.code } },
  ),
});

describe('PushService', () => {
  const makePrisma = (tokens: string[]) => ({
    deviceToken: {
      findMany: jest.fn().mockResolvedValue(tokens.map((token) => ({ token }))),
      deleteMany: jest.fn().mockResolvedValue({ count: 0 }),
    },
  });

  beforeEach(() => {
    sendEach().mockReset();
    sendEach().mockResolvedValue(batch({ success: true }));
    process.env.FIREBASE_PROJECT_ID = 'taqwa-test';
    process.env.FIREBASE_CLIENT_EMAIL = 'sa@taqwa-test.iam.gserviceaccount.com';
    process.env.FIREBASE_PRIVATE_KEY =
      '-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----';
  });

  /** Configured and initialised, which is what the sending tests assume. */
  const configured = (prisma: unknown) => {
    const service = new PushService(prisma as any);
    service.onModuleInit();
    return service;
  };

  it('pushes to every device the user has registered', async () => {
    const prisma = makePrisma(['tok-phone', 'tok-tablet']);
    sendEach().mockResolvedValue(batch({ success: true }, { success: true }));
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'تم تسجيل غياب Bilal اليوم');

    const [messages] = sendEach().mock.calls[0];
    expect(messages).toHaveLength(2);
    expect(messages[0]).toMatchObject({
      token: 'tok-phone',
      notification: { title: 'غياب', body: 'تم تسجيل غياب Bilal اليوم' },
    });
    expect(messages[1].token).toBe('tok-tablet');
  });

  it('carries the route the app opens on a tap', async () => {
    const prisma = makePrisma(['tok-phone']);
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'نص');

    const [messages] = sendEach().mock.calls[0];
    expect(messages[0].data).toEqual({ route: 'notifications' });
  });

  it('does not call FCM for a user with no devices', async () => {
    // A parent who never opened the app, or refused the permission. The
    // notification row is still written by the caller either way.
    const prisma = makePrisma([]);
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'نص');

    expect(sendEach()).not.toHaveBeenCalled();
  });

  it('deletes a token FCM reports as permanently gone', async () => {
    const prisma = makePrisma(['tok-live', 'tok-dead']);
    sendEach().mockResolvedValue(
      batch(
        { success: true },
        { success: false, code: 'messaging/registration-token-not-registered' },
      ),
    );
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'نص');

    expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { token: { in: ['tok-dead'] } },
    });
  });

  it('keeps a token that failed for a passing reason', async () => {
    // FCM being briefly unavailable says nothing about the device. Pruning on
    // it would unsubscribe a working phone that simply could not be reached.
    const prisma = makePrisma(['tok-live']);
    sendEach().mockResolvedValue(
      batch({ success: false, code: 'messaging/server-unavailable' }),
    );
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'نص');

    expect(prisma.deviceToken.deleteMany).not.toHaveBeenCalled();
  });

  it('reads only the tokens belonging to that user', async () => {
    const prisma = makePrisma(['tok-phone']);
    const service = configured(prisma);

    await service.sendToUser(9, 'غياب', 'نص');

    expect(prisma.deviceToken.findMany).toHaveBeenCalledWith(
      expect.objectContaining({ where: { userId: 9 } }),
    );
  });
});

describe('PushService configuration', () => {
  const FIREBASE_KEYS = [
    'FIREBASE_PROJECT_ID',
    'FIREBASE_CLIENT_EMAIL',
    'FIREBASE_PRIVATE_KEY',
  ];

  const makePrisma = () => ({
    deviceToken: { findMany: jest.fn(), deleteMany: jest.fn() },
  });

  beforeEach(() => {
    for (const key of FIREBASE_KEYS) delete process.env[key];
    sendEach().mockReset();
  });

  it('boots with push disabled when Firebase is not configured at all', () => {
    // Until the Firebase project exists, the API still has to start. Every
    // other feature works without push, and the notification rows are still
    // written and readable in the app.
    const service = new PushService(makePrisma() as any);

    expect(() => service.onModuleInit()).not.toThrow();
  });

  it('sends nothing, and asks the database for nothing, while disabled', async () => {
    const prisma = makePrisma();
    const service = new PushService(prisma as any);
    service.onModuleInit();

    await service.sendToUser(9, 'غياب', 'نص');

    expect(prisma.deviceToken.findMany).not.toHaveBeenCalled();
    expect(sendEach()).not.toHaveBeenCalled();
  });

  it('refuses to start on a half-configured deployment', () => {
    // Two of three set is a mistake being made, not a deliberate opt-out, and
    // silently disabling push would hide it until a parent noticed.
    process.env.FIREBASE_PROJECT_ID = 'taqwa-test';
    const service = new PushService(makePrisma() as any);

    expect(() => service.onModuleInit()).toThrow(/FIREBASE_CLIENT_EMAIL/);
  });
});
