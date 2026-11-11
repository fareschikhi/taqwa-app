import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/last_seen.dart';

void main() {
  final now = DateTime(2026, 11, 11, 15, 30);
  String label(DateTime? seen) => lastSeenLabel(seen, now: now);
  DateTime daysAgo(int d) => DateTime(2026, 11, 11, 9).subtract(Duration(days: d));

  group('lastSeenLabel', () {
    test('never seen', () {
      expect(label(null), 'لم يدخل التطبيق بعد');
    });

    test('earlier today', () {
      expect(label(DateTime(2026, 11, 11, 0, 5)), 'آخر دخول: اليوم');
    });

    // Calendar days, not 24-hour blocks: 23:50 last night is "yesterday".
    test('late last night is yesterday', () {
      expect(label(DateTime(2026, 11, 10, 23, 50)), 'آخر دخول: أمس');
    });

    test('days use the Arabic dual and plural', () {
      expect(label(daysAgo(2)), 'آخر دخول: منذ يومين');
      expect(label(daysAgo(3)), 'آخر دخول: منذ 3 أيام');
      expect(label(daysAgo(6)), 'آخر دخول: منذ 6 أيام');
    });

    test('weeks', () {
      expect(label(daysAgo(7)), 'آخر دخول: منذ أسبوع');
      expect(label(daysAgo(14)), 'آخر دخول: منذ أسبوعين');
      expect(label(daysAgo(21)), 'آخر دخول: منذ 3 أسابيع');
      expect(label(daysAgo(29)), 'آخر دخول: منذ 4 أسابيع');
    });

    test('months', () {
      expect(label(daysAgo(30)), 'آخر دخول: منذ شهر');
      expect(label(daysAgo(60)), 'آخر دخول: منذ شهرين');
      expect(label(daysAgo(150)), 'آخر دخول: منذ 5 أشهر');
      expect(label(daysAgo(340)), 'آخر دخول: منذ 11 شهراً');
    });

    test('over a year', () {
      expect(label(daysAgo(400)), 'آخر دخول: منذ أكثر من سنة');
    });

    // A phone clock running a little behind the server's must not say
    // "in 2 days".
    test('a time in the future reads as today', () {
      expect(label(DateTime(2026, 11, 13)), 'آخر دخول: اليوم');
    });
  });

  group('isStaleLastSeen', () {
    test('never seen is not stale, it is its own case', () {
      expect(isStaleLastSeen(null, now: now), isFalse);
    });

    test('a month or more away is stale', () {
      expect(isStaleLastSeen(daysAgo(29), now: now), isFalse);
      expect(isStaleLastSeen(daysAgo(30), now: now), isTrue);
    });
  });
}
