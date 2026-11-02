import {
  DELETED_LABEL,
  PHOTO_LABEL,
  STAFF_LABEL,
  previewOf,
  toMessageDto,
} from './chat-serializer';

const at = new Date('2026-11-02T10:00:00Z');

const staffMessage = {
  id: 7,
  senderUserId: 55,
  fromStaff: true,
  body: 'نرجو إرسال سبب الغياب',
  imagePath: null,
  editedAt: null,
  deletedAt: null,
  createdAt: at,
  updatedAt: at,
  sender: { fullName: 'أحمد بن سالم' },
};

const parentMessage = {
  ...staffMessage,
  id: 8,
  senderUserId: 30,
  fromStaff: false,
  body: 'كان مريضاً',
  sender: { fullName: 'محمد بن علي' },
};

const parentViewer = { isStaff: false };
const staffViewer = { isStaff: true };

describe('toMessageDto', () => {
  it('shows a staff message to the parent as الإدارة with no trace of the sender', () => {
    const dto = toMessageDto(staffMessage, parentViewer, 'محمد بن علي');

    expect(dto.senderName).toBe(STAFF_LABEL);
    expect(dto).not.toHaveProperty('staffSenderName');
    const json = JSON.stringify(dto);
    expect(json).not.toContain('أحمد');
    expect(json).not.toContain('55');
    expect(json).not.toContain('senderUserId');
  });

  it('gives staff the colleague first name on a staff message', () => {
    const dto = toMessageDto(staffMessage, staffViewer, 'محمد بن علي');

    expect(dto.senderName).toBe(STAFF_LABEL);
    expect(dto.staffSenderName).toBe('أحمد');
    expect(dto.mine).toBe(true);
  });

  it('names the parent on their own messages', () => {
    const dto = toMessageDto(parentMessage, staffViewer, 'محمد بن علي');

    expect(dto.senderName).toBe('محمد بن علي');
    expect(dto.mine).toBe(false);
    expect(dto.fromStaff).toBe(false);
  });

  it('lets each side change only its own side', () => {
    expect(toMessageDto(parentMessage, parentViewer, 'p').canEdit).toBe(true);
    expect(toMessageDto(staffMessage, parentViewer, 'p').canEdit).toBe(false);
    expect(toMessageDto(staffMessage, staffViewer, 'p').canDelete).toBe(true);
    expect(toMessageDto(parentMessage, staffViewer, 'p').canDelete).toBe(false);
  });

  it('carries no body or image for a deleted message, and it cannot be changed', () => {
    const dto = toMessageDto(
      { ...parentMessage, imagePath: '.chat/a.jpg', deletedAt: at },
      parentViewer,
      'p',
    );

    expect(dto).toMatchObject({
      deleted: true,
      body: null,
      hasImage: false,
      canEdit: false,
      canDelete: false,
    });
  });

  it('lets the owner delete but not edit a photo with no caption', () => {
    const dto = toMessageDto(
      { ...parentMessage, body: null, imagePath: '.chat/a.jpg' },
      parentViewer,
      'p',
    );

    expect(dto.hasImage).toBe(true);
    expect(dto.canEdit).toBe(false);
    expect(dto.canDelete).toBe(true);
  });

  it('marks an edited message', () => {
    expect(
      toMessageDto({ ...parentMessage, editedAt: at }, parentViewer, 'p')
        .edited,
    ).toBe(true);
  });

  it('has no staff name when the sender account is gone', () => {
    const dto = toMessageDto(
      { ...staffMessage, senderUserId: null, sender: null },
      staffViewer,
      'p',
    );

    expect(dto.staffSenderName).toBeUndefined();
    expect(dto.senderName).toBe(STAFF_LABEL);
  });
});

describe('previewOf', () => {
  it('never reveals the text of a deleted message', () => {
    expect(previewOf({ ...staffMessage, deletedAt: at })).toBe(DELETED_LABEL);
  });

  it('describes a photo with no caption', () => {
    expect(previewOf({ ...parentMessage, body: null, imagePath: 'x' })).toBe(
      PHOTO_LABEL,
    );
  });

  it('prefixes a staff message with الإدارة', () => {
    expect(previewOf(staffMessage)).toBe('الإدارة: نرجو إرسال سبب الغياب');
  });

  it('uses the parent text as is', () => {
    expect(previewOf(parentMessage)).toBe('كان مريضاً');
  });
});
