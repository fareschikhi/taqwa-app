import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/confirm_logout_dialog.dart';
import 'pages/admin_dashboard_page.dart';
import 'pages/students_management_page.dart';
import 'pages/halaqas_management_page.dart';
import 'pages/teachers_management_page.dart';
import 'pages/managers_management_page.dart';
import 'pages/parents_management_page.dart';
import 'pages/reports_page.dart';
import 'package:taqwa/core/providers/chat_unread_provider.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/chat/data/chat_push.dart';
import 'package:taqwa/features/chat/presentation/pages/chat_inbox_page.dart';
import 'package:taqwa/features/shared/presentation/pages/profile_page.dart';

/// Drawer positions other admin pages jump to. Chat sits second, so the
/// administration sees parents' messages one tap from the dashboard.
abstract final class AdminTabs {
  static const dashboard = 0;
  static const chat = 1;
  static const students = 2;
  static const halaqas = 3;
  static const teachers = 4;
  static const managers = 5;
}

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

class AdminShell extends ConsumerStatefulWidget {
  const AdminShell({super.key});

  @override
  ConsumerState<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends ConsumerState<AdminShell> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = const [
    AdminDashboardPage(),
    ChatInboxPage(),
    StudentsManagementPage(),
    HalaqasManagementPage(),
    TeachersManagementPage(),
    ManagersManagementPage(),
    ParentsManagementPage(),
    ReportsPage(),
    ProfilePage(role: 'admin'),
  ];

  Future<void> _logout() async {
    Navigator.pop(context);
    final confirmed = await ConfirmLogoutDialog.show(context);
    if (!confirmed) return;
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    // AuthGate is the root and shows the login form itself once the session
    // is gone. This only clears anything pushed on top of it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(chatUnreadProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatPushEventsProvider, (_, next) {
      if (next.value?['route'] == 'chat') {
        ref.read(chatUnreadProvider.notifier).refresh();
      }
    });
    // A tapped chat notification opens the inbox.
    ref.listen(chatPushTapsProvider, (_, next) {
      if (next.value?['route'] == 'chat') {
        setState(() => _currentIndex = AdminTabs.chat);
      }
    });

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
    final unread = ref.watch(chatUnreadProvider);
    final items = [
      _NavItemData(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'الرئيسية',
        index: AdminTabs.dashboard,
      ),
      _NavItemData(
        icon: Icons.forum_outlined,
        activeIcon: Icons.forum,
        label: 'المحادثات',
        index: AdminTabs.chat,
        badge: unread,
      ),
      _NavItemData(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'الطلاب',
        index: AdminTabs.students,
      ),
      _NavItemData(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'الحلقات',
        index: AdminTabs.halaqas,
      ),
      _NavItemData(
        icon: Icons.badge_outlined,
        activeIcon: Icons.badge,
        label: 'المعلمون',
        index: AdminTabs.teachers,
      ),
      _NavItemData(
        icon: Icons.manage_accounts_outlined,
        activeIcon: Icons.manage_accounts,
        label: 'الإدارة',
        index: AdminTabs.managers,
      ),
      _NavItemData(
        icon: Icons.family_restroom_outlined,
        activeIcon: Icons.family_restroom,
        label: 'أولياء الأمور',
        index: 6,
      ),
      _NavItemData(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart,
        label: 'التقارير',
        index: 7,
      ),
      _NavItemData(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'الحساب',
        index: 8,
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
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusMd,
                      ),
                    ),
                    child: AppLogo(height: 30.w),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'التقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        AppText(
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
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
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
                          AppText(
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
                          if (item.badge > 0) ...[
                            const Spacer(),
                            Container(
                              constraints: BoxConstraints(minWidth: 22.w),
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 1.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull,
                                ),
                              ),
                              child: AppText(
                                '${item.badge}',
                                textAlign: TextAlign.center,
                                semanticsLabel: '${item.badge} رسائل جديدة',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 12.h),
            const Divider(color: AppColors.outlineVariant, height: 1),
            SizedBox(height: 12.h),
            // Logout
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: InkWell(
                onTap: _logout,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: AppColors.error, size: 22.w),
                      SizedBox(width: 14.w),
                      AppText(
                        'تسجيل الخروج',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 12.h),
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
    this.badge = 0,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;

  /// An unread count shown after the label; 0 shows nothing.
  final int badge;
}
