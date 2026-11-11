import '../constants/surahs.dart';
import '../enums/memorization_subject.dart';
import '../enums/memorization_type.dart';

/// One thing the child recited on the day of their last attendance.
class LastSessionEntry {
  const LastSessionEntry({
    this.surahNumber,
    required this.amount,
    required this.type,
    this.subject = MemorizationSubject.quran,
    this.hadithReference,
    this.countsPages = false,
    this.unit,
    this.ayahFrom,
    this.ayahTo,
  });

  /// The raw API unit (PAGE, HADITH or AYAH), or null on older rows.
  final String? unit;

  /// AYAH-only range inside [surahNumber].
  final int? ayahFrom;
  final int? ayahTo;

  /// QURAN-only; null for a HADITH entry.
  final int? surahNumber;

  /// Pages for any Quran entry; hadiths for a hadith entry unless
  /// [countsPages]. A half page arrives as 1.5.
  final num amount;

  /// A hadith entry the teacher counted in pages. Ignored for Quran, which is
  /// always pages.
  final bool countsPages;

  /// Null when the API sends a type this build does not know about, so an
  /// unfamiliar value costs the label rather than the whole card.
  final MemorizationType? type;

  final MemorizationSubject subject;

  /// HADITH-only free-text identity; null for a QURAN entry.
  final String? hadithReference;

  String? get surahName => surahNameOf(surahNumber);
}

/// The most recent day the child was marked, and what they recited on it.
class LastSession {
  const LastSession({
    required this.date,
    required this.status,
    required this.entries,
  });

  final DateTime date;

  /// The raw API status — PRESENT, LATE or ABSENT — left for the caller to
  /// label, since the wording differs by screen.
  final String status;

  /// Empty when nothing was recorded that day, which is always the case for
  /// an absence: the backend drops the day's memorization with the same write.
  final List<LastSessionEntry> entries;
}

/// Both columns are bare DATEs that Prisma serialises at UTC midnight, but a
/// time component can still ride along. Flooring in UTC is what lets an
/// attendance row and a memorization row taken in the same halaqa match.
DateTime? _utcDay(Object? raw) {
  final parsed = DateTime.tryParse(raw?.toString() ?? '');
  if (parsed == null) return null;
  final utc = parsed.toUtc();
  return DateTime.utc(utc.year, utc.month, utc.day);
}

/// Pairs the newest row of [attendance] with the [memorization] recorded on
/// that same day.
///
/// Returns null when no attendance has been taken yet. The newest row is found
/// by date rather than by position, so the result does not depend on the order
/// the endpoint happened to sort by.
LastSession? lastSessionOf({
  required List<Map<String, dynamic>> attendance,
  required List<Map<String, dynamic>> memorization,
}) {
  Map<String, dynamic>? latest;
  DateTime? latestDay;

  for (final row in attendance) {
    final day = _utcDay(row['date']);
    if (day == null) continue;
    if (latestDay == null || day.isAfter(latestDay)) {
      latestDay = day;
      latest = row;
    }
  }

  if (latest == null || latestDay == null) return null;
  final day = latestDay;

  return LastSession(
    date: day,
    status: latest['status']?.toString() ?? '',
    entries: [
      for (final record in memorization)
        if (_utcDay(record['date']) == day)
          LastSessionEntry(
            subject:
                MemorizationSubjectX.fromApi(record['subject'] as String?) ??
                MemorizationSubject.quran,
            surahNumber: (record['surahNumber'] as num?)?.toInt() ?? 0,
            hadithReference: record['hadithReference'] as String?,
            countsPages: record['unit'] == 'PAGE',
            unit: record['unit'] as String?,
            ayahFrom: (record['ayahFrom'] as num?)?.toInt(),
            ayahTo: (record['ayahTo'] as num?)?.toInt(),
            amount: (record['amountDone'] as num?) ?? 0,
            type: MemorizationTypeX.fromApi(
              record['memorizationType'] as String?,
            ),
          ),
    ],
  );
}
