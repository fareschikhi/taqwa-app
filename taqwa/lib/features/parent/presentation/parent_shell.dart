import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
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
import 'package:taqwa/core/widgets/shell_tab_scope.dart';
import 'package:taqwa/features/data/repositories/notification_repository.dart';
import 'pages/notifications_page.dart';
import 'package:taqwa/core/providers/chat_unread_provider.dart';
import 'package:taqwa/features/chat/presentation/pages/chat_thread_page.dart';
import 'package:taqwa/features/data/models/chat/chat_target.dart';

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
      ref.read(chatUnreadProvider.notifier).refresh();
    });

    // Android shows nothing in the tray while the app is in the foreground,
    // by design. Refreshing the badge is the honest equivalent: the parent is
    // already looking at the screen the notification would have sent them to.
    // The web build never starts Firebase, so there is nothing to listen to.
    if (kIsWeb) return;
    _onMessage = FirebaseMessaging.onMessage.listen((message) {
      _loadUnread();
      if (message.data['route'] == 'chat') {
        ref.read(chatUnreadProvider.notifier).refresh();
      }
    });

    // Tapping a notification that opened the app from the background lands on
    // the tab rather than wherever they last were.
    _onMessageOpened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      if (!mounted) return;
      if (message.data['route'] == 'chat') {
        _openChat();
        return;
      }
      _selectTab(3);
    });
  }

  @override
  void dispose() {
    _onMessage?.cancel();
    _onMessageOpened?.cancel();
    super.dispose();
  }

  /// A chat push opens the conversation itself, not a tab.
  void _openChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ChatThreadPage(target: ChatTarget.mine(), title: 'الإدارة'),
      ),
    );
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
                childState.errorMessage ??
                    'لا يوجد أبناء مسجلون على هذا الحساب',
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
            child: ShellTabScope(
              selectTab: _selectTab,
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildChildSwitcher(SelectedStudentState childState) {
    // Sits on the page background, not a white strip, so it reads as part of
    // the page under it rather than a second app bar.
    return Container(
      color: AppColors.background,
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48.h,
          child: ListView.separated(
            reverse: true,
            scrollDirection: Axis.horizontal,
            itemCount: childState.students.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final child = childState.students[i];
              final isSelected = child.id == childState.selected?.id;
              return Semantics(
                button: true,
                selected: isSelected,
                child: GestureDetector(
                  onTap: () =>
                      ref.read(selectedStudentProvider.notifier).select(child),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    padding: EdgeInsetsDirectional.only(start: 6.w, end: 14.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AvatarWidget(
                          avatarUrl: child.avatar,
                          size: 34.w,
                          fallback: AppText(
                            child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        AppText(
                          child.fullName,
                          style: AppTextStyles.bodyMd.copyWith(
                            fontSize: 15.sp,
                            color: isSelected
                                ? AppColors.onPrimaryContainer
                                : AppColors.onSurfaceVariant,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
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
        icon: Icons.calendar_month_outlined,
        activeIcon: Icons.calendar_month,
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
        border: const Border(top: BorderSide(color: AppColors.cardBorder)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(AppConstants.radiusXl),
          topRight: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
          // The app tree is LTR (see AppText), so the bar is flipped on its
          // own: an Arabic reader starts on the right, with الرئيسية.
          child: Row(
            textDirection: TextDirection.rtl,
            children: List.generate(items.length, (i) {
              final isActive = _currentIndex == i;
              final item = items[i];
              // Equal-width cells: the whole fifth of the bar is the tap
              // target, not just the icon and its label.
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _selectTab(i),
                    child: AnimatedContainer(
                      duration: AppConstants.animFast,
                      margin: EdgeInsets.symmetric(horizontal: 3.w),
                      padding: EdgeInsets.symmetric(vertical: 8.h),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primaryContainer
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusLg,
                        ),
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
                            maxLines: 1,
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
