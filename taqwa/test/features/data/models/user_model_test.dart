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

    // The cached copy is what a returning user's launch routes on, so the
    // flag has to survive being written out and read back.
    test('round-trips the must-change-password flag', () {
      final user = UserModel.fromJson({
        'id': 9,
        'fullName': 'Amine Cherguini',
        'role': 'PARENT',
        'mustChangePassword': true,
      });

      expect(user.mustChangePassword, isTrue);
      expect(UserModel.fromJson(user.toJson()).mustChangePassword, isTrue);
    });

    test('treats a missing flag as no change required', () {
      final user = UserModel.fromJson({
        'id': 9,
        'fullName': 'Amine Cherguini',
        'role': 'PARENT',
      });

      expect(user.mustChangePassword, isFalse);
    });
  });
}
