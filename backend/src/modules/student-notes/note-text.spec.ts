import { normalizeNoteText } from './note-text';

describe('normalizeNoteText', () => {
  it('keeps a single line break', () => {
    expect(normalizeNoteText('أحسن اليوم\nفي المراجعة')).toBe('أحسن اليوم\nفي المراجعة');
  });

  it('keeps one blank line between two sentences', () => {
    expect(normalizeNoteText('أحسن اليوم\n\nفي المراجعة')).toBe('أحسن اليوم\n\nفي المراجعة');
  });

  it('cuts two or more blank lines down to one', () => {
    expect(normalizeNoteText('أحسن اليوم\n\n\nفي المراجعة')).toBe('أحسن اليوم\n\nفي المراجعة');
    expect(normalizeNoteText('أحسن اليوم\n\n\n\n\n\nفي المراجعة')).toBe(
      'أحسن اليوم\n\nفي المراجعة',
    );
  });

  it('treats a line of only spaces as blank', () => {
    expect(normalizeNoteText('أحسن اليوم\n  \n\t\n \nفي المراجعة')).toBe(
      'أحسن اليوم\n\nفي المراجعة',
    );
  });

  it('handles Windows line endings', () => {
    expect(normalizeNoteText('أحسن اليوم\r\n\r\n\r\nفي المراجعة')).toBe(
      'أحسن اليوم\n\nفي المراجعة',
    );
  });

  it('drops blank lines at the start and end', () => {
    expect(normalizeNoteText('\n\n\nأحسن اليوم\n\n\n')).toBe('أحسن اليوم');
  });

  it('leaves spaces inside a line alone', () => {
    expect(normalizeNoteText('أحسن   اليوم')).toBe('أحسن   اليوم');
  });
});
