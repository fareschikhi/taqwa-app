import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';

void main() {
  // The admin adjusts a teacher's points by this id, so it must never be the
  // teacher-row id by mistake.
  group('TeacherModel.userId', () {
    test('reads userId, then user.id', () {
      expect(TeacherModel.fromJson({'id': 5, 'userId': 50}).userId, 50);
      expect(
        TeacherModel.fromJson({
          'id': 5,
          'user': {'id': 50, 'fullName': 'x'},
        }).userId,
        50,
      );
    });

    // A user-shaped row (teacher nested under "teacher"): its own id is the
    // account id.
    test('a user-shaped row uses its own id', () {
      final t = TeacherModel.fromJson({
        'id': 50,
        'fullName': 'x',
        'teacher': {'id': 5},
      });
      expect(t.id, 5);
      expect(t.userId, 50);
    });

    // A teacher row with no account id at all: its id is the *teacher* id,
    // and taking it as the account would point at someone else.
    test('a teacher row without an account id has none', () {
      expect(TeacherModel.fromJson({'id': 5, 'fullName': 'x'}).userId, 0);
    });
  });
}
