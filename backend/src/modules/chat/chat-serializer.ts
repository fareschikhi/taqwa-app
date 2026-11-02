/**
 * Turns stored chat rows into what each side is allowed to see.
 *
 * This is where the administration stays anonymous. The database keeps the
 * real staff sender (accountability, and the staff's own view), and a parent
 * gets a copy with that identity removed — on the server, so it never travels
 * to the phone where anyone could read it out of the network traffic.
 */

/** The only name a parent ever sees on a staff message. */
export const STAFF_LABEL = 'الإدارة';
export const DELETED_LABEL = 'تم حذف هذه الرسالة';
export const PHOTO_LABEL = '📷 صورة';

/** The columns serialization reads; `sender` is the staff or parent user. */
export interface ChatMessageRow {
  id: number;
  senderUserId: number | null;
  fromStaff: boolean;
  body: string | null;
  imagePath: string | null;
  editedAt: Date | null;
  deletedAt: Date | null;
  createdAt: Date;
  updatedAt: Date;
  sender?: { fullName: string } | null;
}

export interface ChatViewer {
  isStaff: boolean;
}

export interface ChatMessageDto {
  id: number;
  /** On the viewer's side of the thread. Staff act as one account, so every staff message is "mine" for staff. */
  mine: boolean;
  fromStaff: boolean;
  senderName: string;
  /** Staff responses only: the colleague who wrote a staff message. */
  staffSenderName?: string;
  body: string | null;
  hasImage: boolean;
  edited: boolean;
  deleted: boolean;
  canEdit: boolean;
  canDelete: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export function toMessageDto(
  message: ChatMessageRow,
  viewer: ChatViewer,
  parentName: string,
): ChatMessageDto {
  const deleted = message.deletedAt !== null;
  // A parent changes their own messages; any staff member changes any staff
  // message. Nobody changes the other side's.
  const ownSide = viewer.isStaff ? message.fromStaff : !message.fromStaff;

  const dto: ChatMessageDto = {
    id: message.id,
    mine: ownSide,
    fromStaff: message.fromStaff,
    senderName: message.fromStaff ? STAFF_LABEL : parentName,
    body: deleted ? null : message.body,
    hasImage: !deleted && message.imagePath !== null,
    edited: message.editedAt !== null,
    deleted,
    canEdit: ownSide && !deleted && message.body !== null,
    canDelete: ownSide && !deleted,
    createdAt: message.createdAt,
    updatedAt: message.updatedAt,
  };

  if (viewer.isStaff && message.fromStaff && message.sender) {
    dto.staffSenderName = firstName(message.sender.fullName);
  }
  return dto;
}

/** One line for the staff inbox. Never the text of a deleted message. */
export function previewOf(message: ChatMessageRow): string {
  const text = messageText(message);
  return message.fromStaff && message.deletedAt === null
    ? `${STAFF_LABEL}: ${text}`
    : text;
}

/** What a push or preview says for a message, before any prefix. */
export function messageText(message: ChatMessageRow): string {
  if (message.deletedAt !== null) return DELETED_LABEL;
  return message.body ?? PHOTO_LABEL;
}

function firstName(fullName: string): string {
  return fullName.trim().split(/\s+/)[0] ?? fullName;
}
