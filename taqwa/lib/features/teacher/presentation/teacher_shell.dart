import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/evaluation_page.dart';
import 'package:taqwa/features/teacher/presentation/pages/memorization_progress_page.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/constants/app_constants.dart';
import 'pages/teacher_dashboard_page.dart';
import 'pages/student_list_page.dart';
import 'pages/attendance_page.dart';
import 'pages/notes_page.dart';
import '../../shared/presentation/pages/profile_page.dart';

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key});

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  int _currentIndex = 0;
  final GlobalKey _dashboardKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      TeacherDashboardPage(key: _dashboardKey),
      // const MemorizationProgressPage(),
      // const EvaluationPage(),
      const StudentListPage(),
      const AttendancePage(),
      const NotesPage(),
      const ProfilePage(role: 'teacher'),
    ];
  }

  void _onTabTapped(int index) {
    if (index == 0 && _currentIndex != 0) {
      dynamic state = _dashboardKey.currentState;
      state?.loadData();
    }
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final items = [
      _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'الرئيسية',
      ),
      _NavItem(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'الطلاب',
      ),
      _NavItem(
        icon: Icons.checklist_rtl,
        activeIcon: Icons.checklist_rtl_outlined,
        label: 'الحضور',
      ),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'الملاحظات',
      ),
      _NavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'الحساب',
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: AppShadows.bottomNav,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radiusXl),
          topRight: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final isActive = _currentIndex == i;
              final item = items[i];
              return GestureDetector(
                onTap: () => _onTabTapped(i),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 16.w : 12.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurfaceVariant,
                        size: 22.w,
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        item.label,
                        style: AppTextStyles.labelSm.copyWith(
                          color: isActive
                              ? AppColors.onPrimaryContainer
                              : AppColors.onSurfaceVariant,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}
