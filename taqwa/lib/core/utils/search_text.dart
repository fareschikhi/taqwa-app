/// Harakat (fatha … sukun, shadda, Quranic marks), superscript alef and
/// tatweel: they change how a name is written, not who it is.
final _ignored = RegExp(r'[ً-ٰٟـ\s]');

const _sameLetter = {
  'أ': 'ا',
  'إ': 'ا',
  'آ': 'ا',
  'ٱ': 'ا',
  'ى': 'ي',
  'ة': 'ه',
};

/// The form a name is compared in: lower case, no diacritics, no spaces, and
/// letters people type interchangeably folded together. So 'عبد الرّحمان'
/// and 'عبدالرحمان' end up identical.
String normalizeForSearch(String text) {
  final stripped = text.toLowerCase().replaceAll(_ignored, '');
  final out = StringBuffer();
  for (final rune in stripped.runes) {
    final char = String.fromCharCode(rune);
    out.write(_sameLetter[char] ?? char);
  }
  return out.toString();
}

/// Whether [query] appears in any of [fields] once both are normalized.
/// A blank query matches everything, so an empty search box shows the list.
bool matchesSearch(String query, Iterable<String?> fields) {
  final q = normalizeForSearch(query);
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && normalizeForSearch(f).contains(q));
}
