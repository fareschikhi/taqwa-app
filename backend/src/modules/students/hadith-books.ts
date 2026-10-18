// The hadith books an admin can assign to a student, in the order the app
// lists them. Must stay identical, character for character, to
// `kHadithBooks` in the app: the teacher's chosen book is stored as the
// entry's `hadithReference` and checked against the student's assignment.
export const HADITH_BOOKS = [
  'الأربعون النووية',
  'المنهاج من ميراث النّبوّة',
  'عُمدة الأحكام',
  'بلوغ المرام من أدلّة الأحكام',
  'الجمع بين الصحيحين',
  'الزوائد على الجمع',
] as const;

// Dedupes and puts the admin's picks in list order, so the stored array and
// the teacher's dropdown read the same way however the boxes were ticked.
export function normalizeHadithBooks(books: readonly string[]): string[] {
  return HADITH_BOOKS.filter((b) => books.includes(b));
}
