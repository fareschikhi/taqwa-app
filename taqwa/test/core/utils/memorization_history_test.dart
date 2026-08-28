import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/memorization_history.dart';

Map<String, dynamic> record({
  String? date,
  String? recordedAt,
  int surahNumber = 1,
}) => {
  'date': date,
  'recordedAt': recordedAt,
  'surahNumber': surahNumber,
};

void main() {
  group('recentMemorization', () {
    // The endpoint sorts by surah number, so the newest entry can arrive
    // anywhere in the list.
    test('puts the newest day first whatever order the API sent', () {
      final recent = recentMemorization([
        record(date: '2026-08-01', surahNumber: 2),
        record(date: '2026-08-20', surahNumber: 5),
        record(date: '2026-08-10', surahNumber: 9),
      ]);

      expect(
        recent.map((r) => r['surahNumber']),
        [5, 9, 2],
      );
    });

    test('keeps only the ten most recent entries', () {
      final recent = recentMemorization([
        for (var day = 1; day <= 14; day++)
          record(
            date: '2026-08-${day.toString().padLeft(2, '0')}',
            surahNumber: day,
          ),
      ]);

      expect(recent, hasLength(10));
      expect(recent.first['surahNumber'], 14);
      expect(recent.last['surahNumber'], 5);
    });

    test('honours a caller-supplied limit', () {
      final recent = recentMemorization([
        record(date: '2026-08-01'),
        record(date: '2026-08-02'),
        record(date: '2026-08-03'),
      ], limit: 2);

      expect(recent, hasLength(2));
    });

    // Two entries can share a day when a student recites twice in one halaqa.
    test('breaks a same-day tie on the recording time', () {
      final recent = recentMemorization([
        record(
          date: '2026-08-05',
          recordedAt: '2026-08-05T08:00:00.000Z',
          surahNumber: 3,
        ),
        record(
          date: '2026-08-05',
          recordedAt: '2026-08-05T11:00:00.000Z',
          surahNumber: 7,
        ),
      ]);

      expect(recent.map((r) => r['surahNumber']), [7, 3]);
    });

    // A row the parent cannot date is the one least worth the limited space.
    test('sorts an undatable entry last', () {
      final recent = recentMemorization([
        record(date: null, recordedAt: null, surahNumber: 4),
        record(date: '2026-01-01', surahNumber: 6),
      ]);

      expect(recent.map((r) => r['surahNumber']), [6, 4]);
    });

    test('leaves the caller list untouched', () {
      final history = [
        record(date: '2026-08-01', surahNumber: 2),
        record(date: '2026-08-20', surahNumber: 5),
      ];

      recentMemorization(history);

      expect(history.map((r) => r['surahNumber']), [2, 5]);
    });

    test('returns nothing for an empty history', () {
      expect(recentMemorization([]), isEmpty);
    });
  });
}
