import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/enums/memorization_type.dart';
import 'package:taqwa/core/utils/last_session.dart';

/// Builds the shape `GET /attendance/student/:id` returns. The column is a
/// bare DATE, so the API always serialises it at UTC midnight.
Map<String, dynamic> attendance(String date, String status) {
  return {
    'id': date.hashCode,
    'date': '${date}T00:00:00.000Z',
    'status': status,
  };
}

/// Builds one row of the `records` list inside the memorization progress
/// payload.
Map<String, dynamic> memorization(
  String date, {
  int surahNumber = 2,
  int amountDone = 3,
  String type = 'MEMORIZING',
}) {
  return {
    'id': '$date$surahNumber$type'.hashCode,
    'date': '${date}T00:00:00.000Z',
    'surahNumber': surahNumber,
    'amountDone': amountDone,
    'memorizationType': type,
  };
}

void main() {
  group('lastSessionOf', () {
    test('returns nothing when the child has no attendance history', () {
      final session = lastSessionOf(attendance: [], memorization: []);

      expect(session, isNull);
    });

    test('reports the date and status of the most recent attendance row', () {
      final session = lastSessionOf(
        attendance: [
          attendance('2026-08-27', 'PRESENT'),
          attendance('2026-08-24', 'ABSENT'),
        ],
        memorization: [],
      );

      expect(session!.date, DateTime.utc(2026, 8, 27));
      expect(session.status, 'PRESENT');
    });

    test('picks the newest row even when the history arrives out of order', () {
      final session = lastSessionOf(
        attendance: [
          attendance('2026-08-24', 'ABSENT'),
          attendance('2026-08-27', 'LATE'),
          attendance('2026-08-25', 'PRESENT'),
        ],
        memorization: [],
      );

      expect(session!.date, DateTime.utc(2026, 8, 27));
      expect(session.status, 'LATE');
    });

    test('keeps only the memorization recorded on that same day', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [
          memorization('2026-08-27', surahNumber: 2),
          memorization('2026-08-24', surahNumber: 3),
        ],
      );

      expect(session!.entries, hasLength(1));
      expect(session.entries.single.surahNumber, 2);
    });

    test('matches the day even when the two timestamps differ in time', () {
      final session = lastSessionOf(
        attendance: [
          {'date': '2026-08-27T00:00:00.000Z', 'status': 'PRESENT'},
        ],
        memorization: [
          {
            'date': '2026-08-27T13:45:09.000Z',
            'surahNumber': 2,
            'amountDone': 3,
            'memorizationType': 'MEMORIZING',
          },
        ],
      );

      expect(session!.entries, hasLength(1));
    });

    test('carries every entry recorded that day, in the order given', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [
          memorization('2026-08-27', surahNumber: 2, type: 'MEMORIZING'),
          memorization('2026-08-27', surahNumber: 18, type: 'SMALLREVISION'),
        ],
      );

      expect(session!.entries.map((e) => e.surahNumber), [2, 18]);
    });

    test('leaves an absent day with no entries', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'ABSENT')],
        memorization: [memorization('2026-08-24')],
      );

      expect(session!.status, 'ABSENT');
      expect(session.entries, isEmpty);
    });

    test('reads the amount and type off each entry', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [
          memorization('2026-08-27', amountDone: 2, type: 'BIGREVISION'),
        ],
      );

      expect(session!.entries.single.amount, 2);
      expect(session.entries.single.type, MemorizationType.majorReview);
    });

    test('resolves the surah number to its name', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [memorization('2026-08-27', surahNumber: 2)],
      );

      expect(session!.entries.single.surahName, 'البقرة');
    });

    test('leaves the surah name empty when the number is off the mushaf', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [memorization('2026-08-27', surahNumber: 0)],
      );

      expect(session!.entries.single.surahName, isNull);
    });

    test('keeps an entry whose type the app does not recognise', () {
      final session = lastSessionOf(
        attendance: [attendance('2026-08-27', 'PRESENT')],
        memorization: [memorization('2026-08-27', type: 'TAJWEED')],
      );

      expect(session!.entries.single.type, isNull);
      expect(session.entries.single.amount, 3);
    });

    test('ignores an attendance row whose date will not parse', () {
      final session = lastSessionOf(
        attendance: [
          {'date': 'not-a-date', 'status': 'PRESENT'},
          attendance('2026-08-24', 'ABSENT'),
        ],
        memorization: [],
      );

      expect(session!.date, DateTime.utc(2026, 8, 24));
      expect(session.status, 'ABSENT');
    });
  });
}
