import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/parent/parent_model.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';

void main() {
  // isActive lives on User, so toggling it needs the user's id, not the
  // parent's or student's own id. The API returns it nested; the models
  // previously dropped it.
  test('ParentModel keeps the nested user id', () {
    final parent = ParentModel.fromJson({
      'id': 7,
      'user': {'id': 42, 'fullName': 'ولي أمر', 'isActive': true},
    });

    expect(parent.id, 7);
    expect(parent.userId, 42);
  });

  test('StudentModel keeps the nested user id', () {
    final student = StudentModel.fromJson({
      'id': 3,
      'user': {'id': 99, 'fullName': 'طالب', 'isActive': false},
    });

    expect(student.id, 3);
    expect(student.userId, 99);
  });
}
