/// The hadith books an admin assigns to a student and a teacher then picks
/// from on the recitation sheet. The chosen name is sent as the entry's
/// `hadithReference`, so older free-text entries still display as they were
/// typed. Must match `HADITH_BOOKS` in the backend character for character:
/// the server refuses a book that is not on the student's list.
const List<String> kHadithBooks = [
  'الأربعون النووية',
  'المنهاج من ميراث النّبوّة',
  'عُمدة الأحكام',
  'بلوغ المرام من أدلّة الأحكام',
  'الجمع بين الصحيحين',
  'الزوائد على الجمع',
];

/// A student's assigned books from the API's `hadithBooks`, in [kHadithBooks]
/// order with unknown names dropped. A payload without the list (an older
/// server, or a roster cached before the list existed) falls back on
/// `tracksHadith`: hadith used to be all-or-nothing, so on means every book.
List<String> parseHadithBooks(Object? raw, {bool tracksHadith = false}) {
  if (raw is List) {
    return kHadithBooks.where(raw.contains).toList();
  }
  return tracksHadith ? List.of(kHadithBooks) : const [];
}
