import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/selected_student_provider.dart';
import '../../../core/widgets/avatar_widget.dart';
import 'pages/parent_dashboard_page.dart';
import 'pages/child_progress_page.dart';
import 'pages/child_attendance_history_page.dart';
import '../../shared/presentation/pages/profile_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/repositories/notification_repository.dart';
import 'pages/notifications_page.dart';

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _currentIndex = 0;

  /// Not const: the notifications page takes a callback so the badge can be
  /// refreshed after one is read.
  late final List<Widget> _pages;

  int _unread = 0;

  StreamSubscription<RemoteMessage>? _onMessage;
  StreamSubscription<RemoteMessage>? _onMessageOpened;

  @override
  void initState() {
    super.initState();
    _pages = [
      const ParentDashboardPage(),
      const ChildProgressPage(),
      const ChildAttendanceHistoryPage(),
      NotificationsPage(onChanged: _loadUnread),
      const ProfilePage(role: 'parent'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(selectedStudentProvider.notifier).load();
      _loadUnread();
    });

    // Android shows nothing in the tray while the app is in the foreground,
    // by design. Refreshing the badge is the honest equivalent: the parent is
    // already looking at the screen the notification would have sent them to.
    _onMessage = FirebaseMessaging.onMessage.listen((_) => _loadUnread());

    // Tapping a notification that opened the app from the background lands on
    // the tab rather than wherever they last were.
    _onMessageOpened = FirebaseMessaging.onMessageOpenedApp.listen((_) {
      if (!mounted) return;
      _selectTab(3);
    });
  }

  @override
  void dispose() {
    _onMessage?.cancel();
    _onMessageOpened?.cancel();
    super.dispose();
  }

  /// The badge counts what the ملاحظات tab would show: the selected child's
  /// news, not every child's.
  int? get _childId => ref.read(selectedStudentProvider).selected?.id;

  Future<void> _loadUnread() async {
    final childId = _childId;
    try {
      final count = await NotificationRepository().unreadCount(
        studentId: childId,
      );
      if (mounted && childId == _childId) setState(() => _unread = count);
    } catch (_) {
      // The badge is a nicety; a failure must not break the shell.
    }
  }

  void _selectTab(int i) {
    setState(() => _currentIndex = i);
    if (i == 3) _clearUnread();
  }

  /// Opening ملاحظات counts as seeing them: the badge goes at once and the
  /// server is told, so it does not come back on the next refresh. The cards
  /// already on screen keep their unread tint until the list reloads.
  Future<void> _clearUnread() async {
    setState(() => _unread = 0);
    try {
      await NotificationRepository().markAllRead(studentId: _childId);
    } catch (_) {
      // Same as loading: the badge must not break the shell.
    }
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(selectedStudentProvider);

    ref.listen(selectedStudentProvider, (previous, next) {
      if (next.selected?.id == previous?.selected?.id) return;
      // Already looking at the tab: the new child's list is on screen, so it
      // counts as seen just as opening the tab would.
      _currentIndex == 3 ? _clearUnread() : _loadUnread();
    });

    if (childState.isLoading && childState.students.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (childState.students.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: AppText(
                childState.errorMessage ?? 'لا يوجد أبناء مسجلون على هذا الحساب',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          if (childState.students.length > 1) _buildChildSwitcher(childState),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildChildSwitcher(SelectedStudentState childState) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56.h,
          child: ListView.separated(
            reverse: true,
            scrollDirection: Axis.horizontal,
            itemCount: childState.students.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final child = childState.students[i];
              final isSelected = child.id == childState.selected?.id;
              return GestureDetector(
                onTap: () =>
                    ref.read(selectedStudentProvider.notifier).select(child),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.outlineVariant,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AvatarWidget(
                        avatarUrl: child.avatar,
                        size: 28.w,
                        fallback: AppText(
                          child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      AppText(
                        child.fullName,
                        style: AppTextStyles.labelMd.copyWith(
                          color: isSelected
                              ? AppColors.onPrimaryContainer
                              : AppColors.onSurfaceVariant,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
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
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book,
        label: 'المقرأة',
      ),
      _NavItem(
        icon: Icons.emoji_events_outlined,
        activeIcon: Icons.emoji_events,
        label: 'الحضور',
      ),
      _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'ملاحظات',
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
                onTap: () => _selectTab(i),
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
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Icon(
                            isActive ? item.activeIcon : item.icon,
                            color: isActive
                                ? AppColors.onPrimaryContainer
                                : AppColors.onSurfaceVariant,
                            size: 22.w,
                          ),
                          // Index 3 is ملاحظات; the pages list and the nav
                          // items are kept in the same order.
                          if (i == 3 && _unread > 0)
                            Positioned(
                              top: -4,
                              left: -4,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 5.w,
                                  vertical: 1.h,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.error,
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusFull,
                                  ),
                                ),
                                child: AppText(
                                  '$_unread',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      AppText(
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
