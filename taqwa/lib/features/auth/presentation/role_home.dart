import 'package:flutter/widgets.dart';
import 'package:taqwa/features/admin/presentation/admin_shell.dart';
import 'package:taqwa/features/adult_student/presentation/adult_student_shell.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/manager/presentation/manager_shell.dart';
import 'package:taqwa/features/parent/presentation/parent_shell.dart';
import 'package:taqwa/features/teacher/presentation/teacher_shell.dart';

/// The shell a signed-in [role] lands on.
///
/// Both ways in — a fresh sign-in and a restored session — read this, so the
/// two can never drift into sending the same role to different screens.
Widget homeForRole(UserRole role) => switch (role) {
  UserRole.admin => const AdminShell(),
  UserRole.teacher => const TeacherShell(),
  UserRole.manager => const ManagerShell(),
  UserRole.adultStudent => const AdultStudentShell(),
  // Parents, and children whose own row carries STUDENT.
  _ => const ParentShell(),
};
