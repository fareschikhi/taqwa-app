import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/attendance_queue.dart';

Map<String, dynamic> record(int studentId, String date, String status) => {
  'studentId': studentId,
  'date': date,
  'status': status,
};

void main() {
  group('mergeQueued', () {
    test('a later mark replaces an earlier one for the same student and day', () {
      // The teacher marked present, the save failed, then they corrected it to
      // absent. Only the correction should reach the server.
      final merged = mergeQueued(
        [record(1, '2026-08-29', 'PRESENT')],
        [record(1, '2026-08-29', 'ABSENT')],
      );

      expect(merged, [record(1, '2026-08-29', 'ABSENT')]);
    });

    test('keeps marks for different students', () {
      final merged = mergeQueued(
        [record(1, '2026-08-29', 'PRESENT')],
        [record(2, '2026-08-29', 'ABSENT')],
      );

      expect(merged.length, 2);
    });

    test('keeps the same student on a different day', () {
      final merged = mergeQueued(
        [record(1, '2026-08-28', 'PRESENT')],
        [record(1, '2026-08-29', 'ABSENT')],
      );

      expect(merged.length, 2);
    });

    test('preserves the order the teacher marked in', () {
      final merged = mergeQueued(
        [record(3, '2026-08-29', 'PRESENT'), record(1, '2026-08-29', 'LATE')],
        [record(2, '2026-08-29', 'ABSENT')],
      );

      expect(merged.map((r) => r['studentId']).toList(), [3, 1, 2]);
    });

    test('an updated record keeps its original position', () {
      final merged = mergeQueued(
        [record(3, '2026-08-29', 'PRESENT'), record(1, '2026-08-29', 'LATE')],
        [record(3, '2026-08-29', 'ABSENT')],
      );

      expect(merged.map((r) => r['studentId']).toList(), [3, 1]);
      expect(merged.first['status'], 'ABSENT');
    });

    test('merging nothing changes nothing', () {
      final existing = [record(1, '2026-08-29', 'PRESENT')];

      expect(mergeQueued(existing, []), existing);
    });
  });

  group('queueKeyFor', () {
    test('two teachers never share a key', () {
      expect(queueKeyFor(4), isNot(queueKeyFor(5)));
    });

    test('the key is stable for one teacher', () {
      expect(queueKeyFor(4), queueKeyFor(4));
    });
  });
}
