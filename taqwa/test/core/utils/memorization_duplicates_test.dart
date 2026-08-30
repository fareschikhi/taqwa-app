import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/memorization_duplicates.dart';

Map<String, dynamic> record({
  int? studentId = 1,
  int surahNumber = 7,
  int amountDone = 2,
  String memorizationType = 'MEMORIZING',
}) => {
  'studentId': studentId,
  'surahNumber': surahNumber,
  'amountDone': amountDone,
  'memorizationType': memorizationType,
};

void main() {
  group('memorizationByStudent', () {
    test('groups every record under its own student', () {
      final grouped = memorizationByStudent([
        record(studentId: 1, surahNumber: 7),
        record(studentId: 2, surahNumber: 9),
        record(studentId: 1, surahNumber: 10),
      ]);

      expect(grouped.keys.toSet(), {1, 2});
      expect(grouped[1], hasLength(2));
      expect(grouped[2], hasLength(1));
    });

    // Entries accumulate rather than replace one another, so a student can
    // legitimately hold several rows for one day and the warning has to be
    // able to list all of them.
    test('keeps the order the API sent for one student', () {
      final grouped = memorizationByStudent([
        record(studentId: 1, surahNumber: 7),
        record(studentId: 1, surahNumber: 10),
      ]);

      expect(grouped[1]!.map((r) => r['surahNumber']), [7, 10]);
    });

    test('drops records carrying no usable student id', () {
      final grouped = memorizationByStudent([
        record(studentId: null),
        record(studentId: 3),
      ]);

      expect(grouped.keys.toSet(), {3});
    });

    test('returns an empty map for no records', () {
      expect(memorizationByStudent([]), isEmpty);
    });
  });

  group('memorizationSummary', () {
    test('names the surah, the type and the amount with its unit', () {
      final summary = memorizationSummary(
        record(surahNumber: 7, amountDone: 2, memorizationType: 'MEMORIZING'),
      );

      expect(summary, 'سورة الأعراف · حفظ جديد · 2 صفحة');
    });

    // Revision is counted in hizbs, so the unit has to follow the type rather
    // than defaulting to pages.
    test('counts revision in hizbs', () {
      final summary = memorizationSummary(
        record(surahNumber: 8, amountDone: 4, memorizationType: 'BIGREVISION'),
      );

      expect(summary, 'سورة الأنفال · مراجعة كبرى · 4 حزب');
    });

    // An unrecognised type falls back to new memorization, matching the column
    // default on the server.
    test('falls back to new memorization for an unknown type', () {
      final summary = memorizationSummary(
        record(surahNumber: 1, amountDone: 1, memorizationType: 'NONSENSE'),
      );

      expect(summary, 'سورة الفاتحة · حفظ جديد · 1 صفحة');
    });

    test('survives a record missing its amount and surah', () {
      final summary = memorizationSummary({'memorizationType': 'MEMORIZING'});

      expect(summary, 'سورة رقم - · حفظ جديد · 0 صفحة');
    });
  });
}
