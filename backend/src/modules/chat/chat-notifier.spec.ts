import { ChatNotifier } from './chat-notifier';
import * as access from './chat-access';

jest.mock('./chat-access');
const mocked = access as jest.Mocked<typeof access>;

describe('ChatNotifier', () => {
  const push = {
    sendToUser: jest.fn().mockResolvedValue(undefined),
    sendToUsers: jest.fn().mockResolvedValue(undefined),
  };
  const notifier = new ChatNotifier({} as any, push as any);
  const message = {
    parentId: 9,
    parentUserId: 30,
    parentName: 'محمد بن علي',
    text: 'كان مريضاً',
  };

  beforeEach(() => {
    jest.clearAllMocks();
    mocked.staffUserIdsForParent.mockResolvedValue([1, 20]);
  });

  it('pushes a staff message to the parent only, as الإدارة', async () => {
    await notifier.messageSent({ ...message, fromStaff: true });

    expect(push.sendToUser).toHaveBeenCalledWith(30, 'الإدارة', 'كان مريضاً', {
      route: 'chat',
      parentId: '9',
    });
    expect(push.sendToUsers).not.toHaveBeenCalled();
  });

  it('pushes a parent message to every staff member in scope', async () => {
    await notifier.messageSent({ ...message, fromStaff: false });

    expect(push.sendToUsers).toHaveBeenCalledWith(
      [1, 20],
      'محمد بن علي',
      'كان مريضاً',
      { route: 'chat', parentId: '9' },
    );
    expect(push.sendToUser).not.toHaveBeenCalled();
  });

  it('never lets a push failure escape', async () => {
    push.sendToUsers.mockRejectedValueOnce(new Error('fcm down'));

    await expect(
      notifier.messageSent({ ...message, fromStaff: false }),
    ).resolves.toBeUndefined();
  });
});
