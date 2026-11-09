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

    test('a teacher row reads the levels they supervise', () {
      final t = TeacherModel.fromJson({
        'id': 6,
        'userId': 42,
        'supervisedLevels': ['ابتدائي', 'ثانوي'],
        'user': {'id': 42, 'fullName': 'Amine', 'role': 'TEACHER'},
      });

      expect(t.supervisedLevels, ['ابتدائي', 'ثانوي']);
    });

    test('the create payload sends an empty list as-is', () {
      final json = const TeacherPayloadDto(
        fullName: 'Amine',
        supervisedLevels: [],
      ).toJson();

      expect(json['supervisedLevels'], isEmpty);
    });
  });
}
