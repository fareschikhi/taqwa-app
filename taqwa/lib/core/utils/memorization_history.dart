/// How many entries a parent is shown at once. The label above the list
/// quotes it, so the cap and the wording cannot drift apart.
const int kRecentMemorizationLimit = 10;

/// `date` is a bare DATE and `recordedAt` a full timestamp, so the day orders
/// the list and the timestamp only settles ties within it.
DateTime? _timestamp(Object? raw) => DateTime.tryParse(raw?.toString() ?? '');

/// The newest [limit] entries of a student's memorization history, newest
/// first.
///
/// The endpoint sorts by surah number, so a parent reading the list top-down
/// would otherwise get the mushaf order rather than their child's recent work.
/// Entries carrying no usable date sort last: they are the ones least worth
/// the limited space.
List<Map<String, dynamic>> recentMemorization(
  List<Map<String, dynamic>> records, {
  int limit = kRecentMemorizationLimit,
}) {
  final sorted = [...records]..sort((a, b) {
    final dayA = _timestamp(a['date']);
    final dayB = _timestamp(b['date']);
    if (dayA == null || dayB == null) {
      if (dayA == dayB) return 0;
      return dayA == null ? 1 : -1;
    }

    final byDay = dayB.compareTo(dayA);
    if (byDay != 0) return byDay;

    final atA = _timestamp(a['recordedAt']);
    final atB = _timestamp(b['recordedAt']);
    if (atA == null || atB == null) return 0;
    return atB.compareTo(atA);
  });

  return sorted.take(limit).toList();
}
