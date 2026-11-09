import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/providers/selected_halaqa_provider.dart';
import 'pages/teacher_dashboard_page.dart';
import 'pages/student_list_page.dart';
import 'pages/attendance_page.dart';
import 'pages/notes_page.dart';
import 'widgets/student_of_month_picker_dialog.dart';
import '../../shared/presentation/pages/profile_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/shell_tab_scope.dart';

class TeacherShell extends ConsumerStatefulWidget {
  const TeacherShell({super.key});

  @override
  ConsumerState<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<TeacherShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey _dashboardKey = GlobalKey();

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pages = [
      TeacherDashboardPage(key: _dashboardKey),
      const StudentListPage(),
      const AttendancePage(),
      const NotesPage(),
      const ProfilePage(role: 'teacher'),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(selectedHalaqaProvider.notifier).load();
      _promptStudentOfMonth();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Coming back to the app counts as entering it again: a teacher who chose
  /// "لاحقاً" is asked once more until the month's pick is validated.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _promptStudentOfMonth();
  }

  Future<void> _promptStudentOfMonth() async {
    if (!mounted) return;
    final validated = await StudentOfMonthPrompt.maybeShow(context);
    if (validated && mounted) {
      dynamic state = _dashboardKey.currentState;
      state?.loadStudentsOfMonth();
    }
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
    final halaqaState = ref.watch(selectedHalaqaProvider);

    // The tabs read the selected halaqa as they first load, so they wait for
    // it rather than fetching every halaqa and then again for one.
    if (halaqaState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return ShellTabScope(
      selectTab: _onTabTapped,
      child: Scaffold(
        body: Column(
          children: [
            if (halaqaState.halaqas.length > 1)
              _buildHalaqaSwitcher(halaqaState),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  /// The same strip a parent with several children gets, one pill per halaqa.
  Widget _buildHalaqaSwitcher(SelectedHalaqaState halaqaState) {
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
            itemCount: halaqaState.halaqas.length,
            separatorBuilder: (_, _) => SizedBox(width: 8.w),
            itemBuilder: (_, i) {
              final halaqa = halaqaState.halaqas[i];
              final isSelected = halaqa.id == halaqaState.selected?.id;
              return Semantics(
                button: true,
                selected: isSelected,
                child: GestureDetector(
                  onTap: () =>
                      ref.read(selectedHalaqaProvider.notifier).select(halaqa),
                  child: AnimatedContainer(
                    duration: AppConstants.animFast,
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryContainer
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 28.w,
                          height: 28.w,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.groups,
                            size: 16.w,
                            color: isSelected
                                ? AppColors.onPrimary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        AppText(
                          halaqa.name,
                          style: AppTextStyles.labelMd.copyWith(
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
