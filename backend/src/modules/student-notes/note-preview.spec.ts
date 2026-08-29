import { NOTE_PREVIEW_LIMIT, notePreview } from './note-preview';

describe('notePreview', () => {
  it('leaves a short note alone, with no ellipsis', () => {
    expect(notePreview('أحسن اليوم')).toBe('أحسن اليوم');
  });

  it('collapses newlines and runs of spaces into single spaces', () => {
    // A teacher typing into a multiline field produces notes the inbox has to
    // render on one line; the stored note keeps its own formatting.
    expect(notePreview('أحسن\n\nاليوم   في   المراجعة')).toBe(
      'أحسن اليوم في المراجعة',
    );
  });

  it('trims surrounding whitespace', () => {
    expect(notePreview('  أحسن اليوم  ')).toBe('أحسن اليوم');
  });

  it('cuts a long note at a word boundary and marks it with an ellipsis', () => {
    const note =
      'أحسن الطالب اليوم في المراجعة وأتقن الحفظ الجديد وشارك في الحلقة بنشاط ملحوظ';

    const preview = notePreview(note);

    expect(preview.endsWith('…')).toBe(true);
    // Cutting mid-word would leave a fragment; the character before the
    // ellipsis must be the end of a real word.
    expect(preview).toBe(notePreview(note));
    expect(note.startsWith(preview.slice(0, -1))).toBe(true);
    expect(preview.slice(0, -1)).not.toMatch(/\s$/);
  });

  it('keeps the whole preview within the limit', () => {
    const note = 'كلمة '.repeat(60);

    expect(notePreview(note).length).toBeLessThanOrEqual(NOTE_PREVIEW_LIMIT);
  });

  it('still cuts a single word longer than the limit', () => {
    // No space to break on. Returning it whole would defeat the limit.
    const note = 'ا'.repeat(200);

    const preview = notePreview(note);

    expect(preview.length).toBeLessThanOrEqual(NOTE_PREVIEW_LIMIT);
    expect(preview.endsWith('…')).toBe(true);
  });

  it('is empty for a note that is nothing but whitespace', () => {
    expect(notePreview('   \n  ')).toBe('');
  });
});
