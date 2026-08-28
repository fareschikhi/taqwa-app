import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/student_grouping.dart';

/// Builds the shape the students endpoints return: a student row carrying an
/// embedded `halaqa` object, or none at all when nobody has enrolled them yet.
Map<String, dynamic> student(String name, {int? halaqaId, String? halaqaName}) {
  return {
    'id': name.hashCode,
    'user': {'fullName': name},
    if (halaqaId != null) 'halaqa': {'id': halaqaId, 'name': halaqaName},
  };
}

void main() {
  group('groupStudentsByHalaqa', () {
    test('collects the students of one halaqa under a single group', () {
      final groups = groupStudentsByHalaqa([
        student('أحمد', halaqaId: 1, halaqaName: 'حلقة الفجر'),
        student('بلال', halaqaId: 1, halaqaName: 'حلقة الفجر'),
      ]);

      expect(groups, hasLength(1));
      expect(groups.first.halaqaId, 1);
      expect(groups.first.name, 'حلقة الفجر');
      expect(groups.first.students, hasLength(2));
    });

    test('keeps the order the backend sent inside a group', () {
      final groups = groupStudentsByHalaqa([
        student('أحمد', halaqaId: 1, halaqaName: 'حلقة الفجر'),
        student('بلال', halaqaId: 1, halaqaName: 'حلقة الفجر'),
      ]);

      final names = groups.first.students
          .map((s) => s['user']['fullName'])
          .toList();
      expect(names, ['أحمد', 'بلال']);
    });

    test('sorts the halaqa groups by name', () {
      final groups = groupStudentsByHalaqa([
        student('عمر', halaqaId: 2, halaqaName: 'حلقة العصر'),
        student('أحمد', halaqaId: 1, halaqaName: 'حلقة الفجر'),
      ]);

      expect(groups.map((g) => g.name), ['حلقة العصر', 'حلقة الفجر']);
    });

    test('pins the students with no halaqa to a last group', () {
      final groups = groupStudentsByHalaqa([
        student('خالد'),
        student('أحمد', halaqaId: 1, halaqaName: 'حلقة الفجر'),
      ]);

      expect(groups, hasLength(2));
      expect(groups.last.halaqaId, isNull);
      expect(groups.last.name, unassignedHalaqaLabel);
      expect(groups.last.students, hasLength(1));
    });

    test('treats a halaqa with a blank name as unassigned', () {
      final groups = groupStudentsByHalaqa([
        student('خالد', halaqaId: 3, halaqaName: ''),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.halaqaId, isNull);
      expect(groups.single.name, unassignedHalaqaLabel);
    });

    test('emits nothing for an empty roster', () {
      expect(groupStudentsByHalaqa(const []), isEmpty);
    });
  });
}
