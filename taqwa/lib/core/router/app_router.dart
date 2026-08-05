import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';

import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/admin/presentation/admin_shell.dart';
import '../../features/teacher/presentation/teacher_shell.dart';
import '../../features/parent/presentation/parent_shell.dart';
import '../../features/manager/presentation/manager_shell.dart';
import '../../features/shared/presentation/pages/notifications_page.dart';
import '../../features/teacher/presentation/pages/student_details_page.dart';
import '../../features/teacher/presentation/pages/attendance_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggingIn = state.matchedLocation == '/login';

      // If not authenticated, force login redirect unless already on login
      if (!authState.isAuthenticated) {
        return isLoggingIn ? null : '/login';
      }

      // If authenticated and on login page, redirect to correct dashboard
      if (isLoggingIn) {
        final role = authState.user?.role;
        if (role == UserRole.admin) return '/admin';
        if (role == UserRole.teacher) return '/teacher';
        if (role == UserRole.manager) return '/manager';
        return '/student-parent';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminShell()),
      GoRoute(
        path: '/teacher',
        builder: (context, state) => const TeacherShell(),
      ),
      GoRoute(
        path: '/student-parent',
        builder: (context, state) => const ParentShell(),
      ),
      GoRoute(
        path: '/manager',
        builder: (context, state) => const ManagerShell(),
      ),
      GoRoute(
        path: '/student/:id',
        builder: (context, state) {
          final name = state.uri.queryParameters['name'] ?? 'عمر خالد';
          return StudentDetailsPage(student: name);
        },
      ),
      GoRoute(
        path: '/attendance/:halaqaId',
        builder: (context, state) {
          return const AttendancePage();
        },
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsPage(),
      ),
    ],
  );
});
