import { DevicesService } from './devices.service';

describe('DevicesService', () => {
  const makePrisma = () => ({
    deviceToken: {
      upsert: jest.fn().mockResolvedValue({ id: 1 }),
      deleteMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
  });

  const TOKEN = 'fcm-token-abc';

  it('claims a device for the signed-in user', async () => {
    const prisma = makePrisma();
    const service = new DevicesService(prisma as any);

    await service.register(9, TOKEN, 'android');

    expect(prisma.deviceToken.upsert).toHaveBeenCalledWith({
      where: { token: TOKEN },
      update: { userId: 9, platform: 'android' },
      create: { userId: 9, token: TOKEN, platform: 'android' },
    });
  });

  it('re-points an existing token instead of storing it twice', async () => {
    // FCM hands the same token back to a reinstalled app, and a shared phone
    // moves between accounts. Keyed on the token, the row follows whoever
    // registered it last rather than leaving the previous user subscribed.
    const prisma = makePrisma();
    const service = new DevicesService(prisma as any);

    await service.register(4, TOKEN, 'android');

    const { where, update } = prisma.deviceToken.upsert.mock.calls[0][0];
    expect(where).toEqual({ token: TOKEN });
    expect(update.userId).toBe(4);
  });

  it('releases the device on sign-out', async () => {
    const prisma = makePrisma();
    const service = new DevicesService(prisma as any);

    await service.unregister(9, TOKEN);

    expect(prisma.deviceToken.deleteMany).toHaveBeenCalledWith({
      where: { token: TOKEN, userId: 9 },
    });
  });

  it('cannot release a device belonging to someone else', async () => {
    // The delete is scoped by the caller as well as the token, so a stolen
    // token cannot be used to silence another parent's phone.
    const prisma = makePrisma();
    const service = new DevicesService(prisma as any);

    await service.unregister(9, TOKEN);

    const { where } = prisma.deviceToken.deleteMany.mock.calls[0][0];
    expect(where.userId).toBe(9);
  });
});
