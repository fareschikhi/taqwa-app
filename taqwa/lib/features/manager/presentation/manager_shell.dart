import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/chat_unread_provider.dart';
import '../../chat/data/chat_push.dart';
import '../../chat/presentation/pages/chat_inbox_page.dart';
import '../../data/models/chat/chat_target.dart';
import 'manager_tabs.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_constants.dart';
import 'pages/manager_dashboard_page.dart';
import 'pages/manager_students_page.dart';
import 'pages/manager_parents_page.dart';
import 'pages/justification_list_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/shared/presentation/pages/profile_page.dart';

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _currentIndex = 0;

  /// The chat tab is there only when the admin granted this manager chat.
  late final bool _canChat = canUseStaffChat(ref.read(authProvider).user);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(chatUnreadProvider.notifier).refresh(),
    );
  }

  late final List<Widget> _pages = [
    ManagerDashboardPage(),
    ManagerStudentsPage(),
    ManagerParentsPage(),
    if (_canChat) const ChatInboxPage(),
    JustificationListPage(),
    ProfilePage(role: 'manager'),
  ];

  @override
  Widget build(BuildContext context) {
    ref.listen(chatPushEventsProvider, (_, next) {
      if (next.value?['route'] == 'chat') {
        ref.read(chatUnreadProvider.notifier).refresh();
      }
    });
    // A tapped chat notification opens the inbox.
    ref.listen(chatPushTapsProvider, (_, next) {
      if (_canChat && next.value?['route'] == 'chat') {
        setState(() => _currentIndex = ManagerTabs.chat);
      }
    });
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  /// A tab icon, with this manager's unread chat count when there is one.
  Widget _withBadge(int count, Widget icon) => count > 0
      ? Badge(
          label: Text('$count'),
          backgroundColor: AppColors.error,
          child: icon,
        )
      : icon;

  Widget _buildBottomNav() {
    final unread = ref.watch(chatUnreadProvider);
    final items = [
      _NavItem(
        icon: Icons.dashboard_outlined,
        activeIcon: Icons.dashboard,
        label: 'الرئيسية',
      ),
      _NavItem(
        icon: Icons.group_outlined,
        activeIcon: Icons.group,
        label: 'الطلاب',
      ),
      _NavItem(
        icon: Icons.family_restroom_outlined,
        activeIcon: Icons.family_restroom,
        label: 'أولياء الأمور',
      ),
      if (_canChat)
        const _NavItem(
          icon: Icons.forum_outlined,
          activeIcon: Icons.forum,
          label: 'المحادثات',
          badge: true,
        ),
      _NavItem(
        icon: Icons.rule_outlined,
        activeIcon: Icons.rule,
        label: 'التبريرات',
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
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
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
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: AppConstants.animFast,
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 20.w : 12.w,
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
                      _withBadge(
                        item.badge ? unread : 0,
                        Icon(
                        isActive ? item.activeIcon : item.icon,
                        color: isActive
                            ? AppColors.onPrimaryContainer
                            : AppColors.onSurfaceVariant,
                        size: 22.w,
                      ),
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
    this.badge = false,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;

  /// Shows the chat unread count on this tab.
  final bool badge;
}
