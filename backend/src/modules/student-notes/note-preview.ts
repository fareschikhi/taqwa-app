/** Longest preview the notification body will carry, ellipsis included. */
export const NOTE_PREVIEW_LIMIT = 60;

/**
 * A one-line preview of a note, for the parent's notification body. The full
 * note stays on the row the parent reads on their dashboard, so this only has
 * to say enough to judge whether it needs reading now.
 *
 * Cutting falls back to the last word boundary before the limit rather than a
 * fixed offset: a fragment of a word reads as corruption rather than as a
 * shortened sentence.
 */
export function notePreview(note: string): string {
  const collapsed = note.replace(/\s+/g, ' ').trim();
  if (collapsed.length <= NOTE_PREVIEW_LIMIT) return collapsed;

  // One character short of the limit, so the ellipsis still fits inside it.
  const cut = collapsed.slice(0, NOTE_PREVIEW_LIMIT - 1);
  const lastSpace = cut.lastIndexOf(' ');
  // A single word longer than the limit has no boundary to fall back to.
  const body = lastSpace > 0 ? cut.slice(0, lastSpace) : cut;
  return `${body}…`;
}
