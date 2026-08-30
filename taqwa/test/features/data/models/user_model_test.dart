import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/user_model.dart';

void main() {
  group('UserModel.fromJson', () {
    test('parses an adult student', () {
      final user = UserModel.fromJson({
        'id': 11,
        'fullName': 'Yacine Belkacem',
        'role': 'ADULT_STUDENT',
        'student': {'id': 21},
      });

      expect(user.role, UserRole.adultStudent);
      expect(user.studentId, 21);
    });

    test('round-trips the adult student role through toJson', () {
      final user = UserModel.fromJson({
        'id': 11,
        'fullName': 'Yacine Belkacem',
        'role': 'ADULT_STUDENT',
        'student': {'id': 21},
      });

      expect(user.toJson()['role'], 'ADULT_STUDENT');
    });

    test('still parses a parent', () {
      final user = UserModel.fromJson({
        'id': 9,
        'fullName': 'Amine Cherguini',
        'role': 'PARENT',
        'parent': {'id': 4},
      });

      expect(user.role, UserRole.parent);
    });
  });
}
