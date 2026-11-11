/// Turns a user's last activity (the server's `lastSeenAt`) into the short
/// label staff read on the parents list: "آخر دخول: منذ 3 أيام".
///
/// Counted in calendar days on the phone's clock, so a parent who opened the
/// app at 23:50 shows "أمس" the next morning, not "اليوم".
String lastSeenLabel(DateTime? lastSeen, {DateTime? now}) {
  if (lastSeen == null) return 'لم يدخل التطبيق بعد';
  return 'آخر دخول: ${timeAgo(lastSeen, now: now)}';
}

/// "اليوم", "أمس", "منذ 3 أيام", "منذ شهرين"… for a past moment.
String timeAgo(DateTime when, {DateTime? now}) =>
    _ago(_daysAgo(when, now ?? DateTime.now()));

/// A month or more without opening the app: worth a phone call too.
bool isStaleLastSeen(DateTime? lastSeen, {DateTime? now}) =>
    lastSeen != null && _daysAgo(lastSeen, now ?? DateTime.now()) >= 30;

int _daysAgo(DateTime lastSeen, DateTime now) {
  final seen = lastSeen.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(seen.year, seen.month, seen.day);
  // Rounded: a daylight-saving switch makes one "day" 23 or 25 hours long.
  final days = (today.difference(day).inHours / 24).round();
  // A server clock ahead of the phone's would otherwise give "in 2 days".
  return days < 0 ? 0 : days;
}

String _ago(int days) {
  if (days == 0) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days < 7) return 'منذ ${_count(days, 'يوم', 'يومين', 'أيام', 'يوماً')}';
  if (days < 30) {
    return 'منذ ${_count(days ~/ 7, 'أسبوع', 'أسبوعين', 'أسابيع', 'أسبوعاً')}';
  }
  if (days < 365) {
    return 'منذ ${_count(days ~/ 30, 'شهر', 'شهرين', 'أشهر', 'شهراً')}';
  }
  return 'منذ أكثر من سنة';
}

/// Arabic counts: one and two are words of their own (شهر، شهرين), 3–10 take
/// the plural (5 أشهر), 11 and up the singular with tanween (11 شهراً).
String _count(int n, String one, String two, String few, String many) {
  if (n == 1) return one;
  if (n == 2) return two;
  if (n <= 10) return '$n $few';
  return '$n $many';
}
