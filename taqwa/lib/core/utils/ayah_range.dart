/// Rules for a Quran entry recorded as an ayah range inside one surah.
///
/// The server checks the same rules, so these only decide what the teacher is
/// told before saving: a range the server would refuse never leaves the sheet.
library;

/// The unit word for ayah entries.
const String kAyahUnitLabel = 'آية';

/// Most ayahs one entry may record: the longest surah (البقرة) has 286. The
/// server applies the same cap, which bounds an ayah count with no surah.
const int kMaxAyahsPerEntry = 286;

/// Why [from]–[to] is not a usable range in a surah of [ayahCount] ayahs, or
/// null when it is. A missing end reads as not filled in yet.
String? ayahRangeError({
  required int? from,
  required int? to,
  required int ayahCount,
}) {
  if (from == null || to == null) return 'أدخل رقم أول آية وآخر آية';
  if (from < 1 || from > ayahCount) {
    return 'رقم «من آية» بين 1 و $ayahCount في هذه السورة';
  }
  if (to < 1 || to > ayahCount) {
    return 'رقم «إلى آية» بين 1 و $ayahCount في هذه السورة';
  }
  if (to < from) return '«إلى آية» لا تكون قبل «من آية»';
  return null;
}

/// How many ayahs [from]–[to] covers, both ends included.
int ayahCountIn(int from, int to) => to - from + 1;

/// Where the next session starts after last session's [lastFrom]–[lastTo]:
/// the ayah after it, the same length again, cut at the surah's end. A range
/// that already reached the end of the surah is offered again as it was,
/// since there is nothing after it to continue with.
({int from, int to}) nextAyahRange({
  required int lastFrom,
  required int lastTo,
  required int ayahCount,
}) {
  if (lastTo >= ayahCount) return (from: lastFrom, to: lastTo);
  final from = lastTo + 1;
  final length = ayahCountIn(lastFrom, lastTo);
  final to = from + length - 1;
  return (from: from, to: to > ayahCount ? ayahCount : to);
}

/// The range as people read it: «الآية 5» for one ayah, «الآيات 1–20» for
/// more. Shown left to right inside the Arabic line so 1–20 never flips.
String ayahRangeLabel(int from, int to) =>
    from == to ? 'الآية $from' : 'الآيات $from–$to';
