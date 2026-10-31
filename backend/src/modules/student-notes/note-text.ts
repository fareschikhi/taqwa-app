/**
 * The note as it is stored: at most one blank line between paragraphs.
 *
 * A teacher pressing Enter a few extra times leaves gaps that push the rest of
 * the note off the parent's screen. One blank line still separates two
 * paragraphs, so any longer run of blank lines is cut down to that. A line
 * holding only spaces counts as blank, and blank lines at either end go.
 */
export function normalizeNoteText(note: string): string {
  return note
    .replace(/\r\n?/g, '\n')
    .replace(/\n[ \t]*\n(?:[ \t]*\n)+/g, '\n\n')
    .trim();
}
