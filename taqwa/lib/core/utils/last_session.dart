import '../constants/surahs.dart';
import '../enums/memorization_type.dart';

/// One thing the child recited on the day of their last attendance.
class LastSessionEntry {
  const LastSessionEntry({
    required this.surahNumber,
    required this.amount,
    required this.type,
  });

  final int surahNumber;

  /// Pages for new memorization, hizbs for revision. Which one it is follows
  /// from [type], so nothing here re-derives the split.
  final int amount;

  /// Null when the API sends a type this build does not know about, so an
  /// unfamiliar value costs the label rather than the whole card.
  final MemorizationType? type;

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
            surahNumber: (record['surahNumber'] as num?)?.toInt() ?? 0,
            amount: (record['amountDone'] as num?)?.toInt() ?? 0,
            type: MemorizationTypeX.fromApi(
              record['memorizationType'] as String?,
            ),
          ),
    ],
  );
}
