import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/weekly_attendance.dart';

/// Builds one entry of the `GET /attendance/week` payload. The column is a
/// bare DATE, so the API always serialises it at UTC midnight.
Map<String, dynamic> day(String date, {int present = 0, int absent = 0}) {
  return {
    'date': '${date}T00:00:00.000Z',
    'present': present,
    'absent': absent,
  };
}

void main() {
  group('weeklyAttendanceFrom', () {
    // 2026-08-23 is a Sunday.
    test('names each day from its own date, Sunday first', () {
      final week = weeklyAttendanceFrom([
        day('2026-08-23', present: 9, absent: 1),
        day('2026-08-24', present: 8, absent: 2),
        day('2026-08-25', present: 7, absent: 3),
        day('2026-08-26', present: 6, absent: 4),
        day('2026-08-27', present: 5, absent: 5),
      ]);

      expect(week.map((d) => d.label), [
        'الأحد',
        'الاثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
      ]);
      expect(week.map((d) => d.present), [9, 8, 7, 6, 5]);
      expect(week.map((d) => d.marked), [10, 10, 10, 10, 10]);
    });

    // An empty bar claims every student missed that day. An unmarked day has
    // to stay distinguishable from that, or the chart libels the halaqa.
    test('keeps an unmarked day distinct from a day everyone missed', () {
      final week = weeklyAttendanceFrom([
        day('2026-08-23'),
        day('2026-08-24', absent: 12),
      ]);

      expect(week[0].marked, 0);
      expect(week[0].hasRecord, isFalse);
      expect(week[1].present, 0);
      expect(week[1].marked, 12);
      expect(week[1].hasRecord, isTrue);
    });

    // Parsing UTC midnight into local time can roll the date back a day in
    // any timezone behind UTC, which would shift every label by one.
    test('reads the weekday in UTC, not local time', () {
      final week = weeklyAttendanceFrom([day('2026-08-23', present: 10)]);

      expect(week.single.label, 'الأحد');
    });

    test('survives a date it cannot read', () {
      final week = weeklyAttendanceFrom([
        {'date': 'not-a-date', 'present': 6, 'absent': 2},
      ]);

      expect(week.single.label, '');
      expect(week.single.present, 6);
    });

    // An older server still sends `rate` and no counts; reading nothing is
    // honest here, since a share cannot be turned back into a head count.
    test('reads a payload with no counts as an unmarked day', () {
      final week = weeklyAttendanceFrom([
        {'date': '2026-08-23T00:00:00.000Z', 'rate': 75},
      ]);

      expect(week.single.hasRecord, isFalse);
    });

    test('survives a payload with nothing in it', () {
      expect(weeklyAttendanceFrom(const []), isEmpty);
    });
  });
}
