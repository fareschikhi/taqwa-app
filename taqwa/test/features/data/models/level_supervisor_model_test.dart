import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/features/data/models/teacher/teacher_payload_dto.dart';

void main() {
  group('معلم مشرف', () {
    test('a halaqa reads the supervisors of its level', () {
      final h = HalaqaModel.fromJson({
        'id': 1,
        'name': 'حلقة النور',
        'level': 'ابتدائي',
        'teacherId': 3,
        'supervisors': [
          {'teacherId': 7, 'fullName': 'Karim', 'avatar': null},
          {'teacherId': 8, 'fullName': 'Salim', 'avatar': '/a.png'},
        ],
      });

      expect(h.supervisors.map((s) => s.teacherId), [7, 8]);
      expect(h.supervisors[1].avatar, '/a.png');
    });

    test('an older payload without supervisors gives an empty list', () {
      final h = HalaqaModel.fromJson({
        'id': 1,
        'name': 'حلقة النور',
        'teacherId': 3,
      });

      expect(h.supervisors, isEmpty);
    });

    test('the phone cache keeps the supervisors', () {
      final h = HalaqaModel.fromJson({
        'id': 1,
        'name': 'حلقة النور',
        'level': 'متوسط',
        'teacherId': 3,
        'supervisors': [
          {'teacherId': 9, 'fullName': 'Nadia', 'avatar': null},
        ],
      });

      final again = HalaqaModel.fromJson(h.toCacheJson());

      expect(again.supervisors.single.fullName, 'Nadia');
    });

    test('a teacher row reads the flag and his halaqa levels', () {
      final t = TeacherModel.fromJson({
        'id': 6,
        'userId': 42,
        'isSupervisor': true,
        'halaqaLevels': ['ابتدائي', 'ثانوي'],
        'user': {'id': 42, 'fullName': 'Amine', 'role': 'TEACHER'},
      });

      expect(t.isSupervisor, isTrue);
      expect(t.halaqaLevels, ['ابتدائي', 'ثانوي']);
    });

    test('an older teacher row is not a supervisor and has no levels', () {
      final t = TeacherModel.fromJson({
        'id': 6,
        'userId': 42,
        'user': {'id': 42, 'fullName': 'Amine', 'role': 'TEACHER'},
      });

      expect(t.isSupervisor, isFalse);
      expect(t.halaqaLevels, isEmpty);
    });

    test('the create payload never sends the flag', () {
      final json = const TeacherPayloadDto(fullName: 'Amine').toJson();

      expect(json.containsKey('isSupervisor'), isFalse);
    });
  });
}
