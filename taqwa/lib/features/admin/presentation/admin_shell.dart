import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/students_management_page.dart';
import 'pages/halaqas_management_page.dart';
import 'pages/teachers_management_page.dart';
import 'pages/managers_management_page.dart';
import 'pages/parents_management_page.dart';
import 'pages/reports_page.dart';

class AdminShellScope extends InheritedWidget {
  final int currentIndex;
  final Function(int) selectTab;
  final VoidCallback openMenu;

  const AdminShellScope({
    super.key,
    required this.currentIndex,
    required this.selectTab,
    required this.openMenu,
    required super.child,
  });

  static AdminShellScope? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AdminShellScope>();
  }

  @override
  bool updateShouldNotify(AdminShellScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = const [
    AdminDashboardPage(),
    StudentsManagementPage(),
    HalaqasManagementPage(),
    TeachersManagementPage(),
    ManagersManagementPage(),
    ParentsManagementPage(),
    ReportsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return AdminShellScope(
      currentIndex: _currentIndex,
      selectTab: (index) => setState(() => _currentIndex = index),
      openMenu: () {
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
        } else {
          _scaffoldKey.currentState?.openDrawer();
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _buildDrawer(context),
        body: IndexedStack(index: _currentIndex, children: _pages),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final items = [
      _NavItemData(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'الرئيسية',
        index: 0,
      ),
      _NavItemData(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'الطلاب',
        index: 1,
      ),
      _NavItemData(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'الحلقات',
        index: 2,
      ),
      _NavItemData(
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge,
        label: 'المعلمون',
        index: 3,
      ),
      _NavItemData(
        icon: Icons.manage_accounts_outlined,
        activeIcon: Icons.manage_accounts,
        label: 'الإدارة',
        index: 4,
      ),
      _NavItemData(
        icon: Icons.family_restroom_outlined,
        activeIcon: Icons.family_restroom,
        label: 'أولياء الأمور',
        index: 5,
      ),
      _NavItemData(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'التقارير',
        index: 6,
      ),
    ];

    return Drawer(
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(height: 16.h),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusMd),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings,
                      color: AppColors.primary,
                      size: 24.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'تقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'لوحة التحكم - الإدارة',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            const Divider(color: AppColors.outlineVariant, height: 1),
            SizedBox(height: 12.h),
            // Menu items
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                itemCount: items.length,
                separatorBuilder: (context, index) => SizedBox(height: 4.h),
                itemBuilder: (context, i) {
                  final item = items[i];
                  final isActive = _currentIndex == item.index;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = item.index);
                    },
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                    child: AnimatedContainer(
                      duration: AppConstants.animFast,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryContainer
                            : Colors.transparent,
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusMd),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                            size: 22.w,
                          ),
                          SizedBox(width: 14.w),
                          Text(
                            item.label,
                            style: AppTextStyles.labelMd.copyWith(
                              color: isActive
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
}
