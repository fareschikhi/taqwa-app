import { NotificationsService } from './notifications.service';

describe('NotificationsService delivery', () => {
  const makePrisma = () => ({
    notification: {
      create: jest
        .fn()
        .mockImplementation(({ data }: any) => Promise.resolve({ id: 1, ...data })),
    },
  });

  const pushMock = () => ({ sendToUser: jest.fn().mockResolvedValue(undefined) });

  const dto = { userId: 9, title: 'غياب', body: 'تم تسجيل غياب Bilal اليوم' };

  it('pushes a created notification to the user it belongs to', async () => {
    // Every producer goes through create(), so putting delivery here is what
    // lets attendance and teacher notes both reach a phone without either
    // knowing that push exists.
    const prisma = makePrisma();
    const push = pushMock();
    const service = new NotificationsService(prisma as any, push as any);

    await service.create(dto);

    expect(push.sendToUser).toHaveBeenCalledWith(
      9,
      'غياب',
      'تم تسجيل غياب Bilal اليوم',
    );
  });

  it('still writes the row when the push fails', async () => {
    const prisma = makePrisma();
    const push = { sendToUser: jest.fn().mockRejectedValue(new Error('down')) };
    const service = new NotificationsService(prisma as any, push as any);

    // The row is the record the parent reads in the app; delivery is an
    // extra. Losing FCM must not lose the notification.
    await expect(service.create(dto)).resolves.toMatchObject({ id: 1 });
    expect(prisma.notification.create).toHaveBeenCalled();
  });

  it('writes the row before attempting delivery', async () => {
    const order: string[] = [];
    const prisma = {
      notification: {
        create: jest.fn().mockImplementation(async () => {
          order.push('write');
          return { id: 1 };
        }),
      },
    };
    const push = {
      sendToUser: jest.fn().mockImplementation(async () => {
        order.push('push');
      }),
    };
    const service = new NotificationsService(prisma as any, push as any);

    await service.create(dto);

    expect(order).toEqual(['write', 'push']);
  });
});
