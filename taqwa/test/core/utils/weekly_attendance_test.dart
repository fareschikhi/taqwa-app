import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/weekly_attendance.dart';

/// Builds one entry of the `GET /attendance/week` payload. The column is a
/// bare DATE, so the API always serialises it at UTC midnight.
Map<String, dynamic> day(String date, {int? rate}) {
  return {
    'date': '${date}T00:00:00.000Z',
    'present': 0,
    'absent': 0,
    'rate': rate,
  };
}

void main() {
  group('weeklyRatesFrom', () {
    // 2026-08-23 is a Sunday.
    test('names each day from its own date, Sunday first', () {
      final week = weeklyRatesFrom([
        day('2026-08-23', rate: 90),
        day('2026-08-24', rate: 80),
        day('2026-08-25', rate: 70),
        day('2026-08-26', rate: 60),
        day('2026-08-27', rate: 50),
      ]);

      expect(week.map((d) => d.label), [
        'الأحد',
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
      ]);
      expect(week.map((d) => d.rate), [90, 80, 70, 60, 50]);
    });

    // A 0% bar claims every student missed that day. An unmarked day has to
    // stay distinguishable from that, or the chart libels the halaqa.
    test('keeps an unmarked day null rather than folding it to zero', () {
      final week = weeklyRatesFrom([day('2026-08-23'), day('2026-08-24', rate: 0)]);

      expect(week[0].rate, isNull);
      expect(week[0].hasRecord, isFalse);
      expect(week[1].rate, 0);
      expect(week[1].hasRecord, isTrue);
    });

    // Parsing UTC midnight into local time can roll the date back a day in
    // any timezone behind UTC, which would shift every label by one.
    test('reads the weekday in UTC, not local time', () {
      final week = weeklyRatesFrom([day('2026-08-23', rate: 100)]);

      expect(week.single.label, 'الأحد');
    });

    test('survives a date it cannot read', () {
      final week = weeklyRatesFrom([
        {'date': 'not-a-date', 'rate': 75},
      ]);

      expect(week.single.label, '');
      expect(week.single.rate, 75);
    });

    test('survives a payload with nothing in it', () {
      expect(weeklyRatesFrom(const []), isEmpty);
    });
  });
}
