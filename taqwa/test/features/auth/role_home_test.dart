import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/admin/presentation/admin_shell.dart';
import 'package:taqwa/features/adult_student/presentation/adult_student_shell.dart';
import 'package:taqwa/features/auth/presentation/role_home.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/manager/presentation/manager_shell.dart';
import 'package:taqwa/features/parent/presentation/parent_shell.dart';
import 'package:taqwa/features/teacher/presentation/teacher_shell.dart';

void main() {
  test('opens the admin shell for an admin', () {
    expect(homeForRole(UserRole.admin), isA<AdminShell>());
  });

  test('opens the teacher shell for a teacher', () {
    expect(homeForRole(UserRole.teacher), isA<TeacherShell>());
  });

  test('opens the manager shell for a manager', () {
    expect(homeForRole(UserRole.manager), isA<ManagerShell>());
  });

  test('opens the adult student shell for an adult student', () {
    expect(homeForRole(UserRole.adultStudent), isA<AdultStudentShell>());
  });

  test('opens the parent shell for a parent', () {
    expect(homeForRole(UserRole.parent), isA<ParentShell>());
  });

  test('opens the parent shell for a child account', () {
    // A child's own row carries STUDENT, and the parent shell is what the app
    // has for it. Sending them to a blank screen instead would be worse.
    expect(homeForRole(UserRole.student), isA<ParentShell>());
  });
}
