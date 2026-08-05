import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/selected_child_provider.dart';
import '../../../core/widgets/avatar_widget.dart';
import 'pages/parent_dashboard_page.dart';
import 'pages/child_progress_page.dart';
import 'pages/child_attendance_history_page.dart';
import '../../shared/presentation/pages/profile_page.dart';

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    ParentDashboardPage(),
    ChildProgressPage(),
    ChildAttendanceHistoryPage(),
    ProfilePage(role: 'parent'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(selectedChildProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(selectedChildProvider);

    if (childState.isLoading && childState.children.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (childState.children.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Text(
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
          if (childState.children.length > 1) _buildChildSwitcher(childState),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildChildSwitcher(SelectedChildState childState) {
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
            itemCount: childState.children.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final child = childState.children[i];
              final isSelected = child.id == childState.selected?.id;
              return GestureDetector(
                onTap: () =>
                    ref.read(selectedChildProvider.notifier).select(child),
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
                        fallback: Text(
                          child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onPrimaryContainer,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
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
                onTap: () => setState(() => _currentIndex = i),
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
