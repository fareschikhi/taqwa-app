import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/weekly_attendance.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/app_card.dart';
import 'package:taqwa/features/data/repositories/student_repository.dart';
import 'package:taqwa/features/data/repositories/teacher_repository.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';
import 'package:taqwa/features/data/repositories/manager_repository.dart';
import '../admin_shell.dart';

class AdminDashboardPage extends ConsumerStatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  ConsumerState<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends ConsumerState<AdminDashboardPage> {
  final _studentRepo = StudentRepository();
  final _teacherRepo = TeacherRepository();
  final _halaqaRepo = HalaqaRepository();
  final _managerRepo = ManagerRepository();
  bool _isLoading = true;
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _halaqasCount = 0;
  int _managersCount = 0;
  String _attendanceRate = '—';
  List<DayAttendanceRate> _week = const [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      // getAllStudents() is capped at the backend's page size, so the real
      // total comes from a separate count call, fetched in parallel with it.
      final studentsCountFuture = _studentRepo.getStudentsCount();
      final results = await Future.wait([
        _studentRepo.getAllStudents(),
        _teacherRepo.getAllTeachers(),
        _halaqaRepo.getAllHalaqas(),
        _managerRepo.getAllManagers(),
      ]);

      final teachers = results[1];
      final halaqas = results[2];
      final managers = results[3];
      final studentsCount = await studentsCountFuture;

      // Compute today's attendance rate from today's records
      String rate = '—';
      try {
        final today = DateTime.now();
        final dateStr =
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
        final attList = await _teacherRepo.getAttendanceByDate(dateStr);
        if (attList.isNotEmpty) {
          // A late arrival is attendance, not an absence — the same rule the
          // server applies to every other rate in the app.
          final present = attList
              .where((a) => a['status'] == 'PRESENT' || a['status'] == 'LATE')
              .length;
          rate = '${((present / attList.length) * 100).round()}%';
        }
      } catch (_) {}

      // The weekly chart is a nicety: if it fails the rest of the dashboard
      // still loads, and the chart says it has nothing rather than inventing
      // a week.
      List<DayAttendanceRate> week = const [];
      try {
        week = weeklyRatesFrom(await _teacherRepo.getWeeklyAttendanceRates());
      } catch (_) {}

      if (mounted) {
        setState(() {
          _studentsCount = studentsCount;
          _teachersCount = teachers.length;
          _halaqasCount = halaqas.length;
          _managersCount = managers.length;
          _attendanceRate = rate;
          _week = week;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final name = user?.fullName ?? 'المسؤول';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadStats,
          child: CustomScrollView(
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppConstants.cardPadding,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 24.h),
                    _buildGreeting(name),
                    SizedBox(height: 24.h),
                    _buildKpiGrid(),
                    SizedBox(height: 24.h),
                    _buildChartAndActivity(),
                    SizedBox(height: 32.h),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => AdminShellScope.of(context)?.openMenu(),
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: const Icon(
                  Icons.menu,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primaryContainer, width: 2),
              ),
              child: Icon(
                Icons.person,
                color: AppColors.onPrimaryContainer,
                size: 22.w,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              'تقوى',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
      toolbarHeight: 56.h,
    );
  }

  Widget _buildGreeting(String name) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'مرحباً بك، $name',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'إليك نظرة عامة على أداء المدرسة القرآنية اليوم.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildKpiGrid() {
    if (_isLoading) {
      return SizedBox(
        height: 180.h,
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12.w,
        mainAxisSpacing: 12.h,
        childAspectRatio: 1.5,
      ),
      children: [
        StatCard(
          value: '$_studentsCount',
          label: 'إجمالي الطلاب',
          icon: Icons.group,
          iconColor: AppColors.primary,
          iconBgColor: AppColors.primaryContainer,
          bubbleColor: AppColors.primaryContainer,
        ),
        StatCard(
          value: '$_teachersCount',
          label: 'المعلمين',
          icon: Icons.badge,
          iconColor: AppColors.secondary,
          iconBgColor: AppColors.secondaryContainer,
          bubbleColor: AppColors.secondaryContainer,
        ),
        StatCard(
          value: _attendanceRate,
          label: 'نسبة الحضور',
          icon: Icons.check_circle,
          iconColor: AppColors.primary,
          iconBgColor: AppColors.primaryContainer,
          bubbleColor: AppColors.primaryContainer,
          valueColor: AppColors.primary,
        ),
        StatCard(
          value: '$_halaqasCount',
          label: 'الحلقات النشطة',
          icon: Icons.menu_book,
          iconColor: AppColors.tertiary,
          iconBgColor: AppColors.tertiaryContainer,
          bubbleColor: AppColors.tertiaryContainer,
        ),
        StatCard(
          value: '$_managersCount',
          label: 'المديرون',
          icon: Icons.manage_accounts,
          iconColor: AppColors.secondary,
          iconBgColor: AppColors.secondaryContainer,
          bubbleColor: AppColors.secondaryContainer,
        ),
      ],
    );
  }

  Widget _buildChartAndActivity() {
    return AppCard(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  'هذا الأسبوع',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                'نسب الحضور',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          if (_week.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 32.h),
              child: Center(
                child: Text(
                  _isLoading ? 'جارٍ التحميل...' : 'لا يوجد سجل حضور هذا الأسبوع',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            SizedBox(height: 120.h, child: _AttendanceBarChart(days: _week)),
        ],
      ),
    );
  }
}

class _AttendanceBarChart extends StatelessWidget {
  const _AttendanceBarChart({required this.days});

  final List<DayAttendanceRate> days;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: days.map((day) => Expanded(child: _bar(day))).toList(),
          ),
        ),
        Divider(color: AppColors.outlineVariant, height: 1),
        SizedBox(height: 8.h),
        // Not reversed: the app runs left-to-right, so a label has to sit under
        // the bar it belongs to rather than mirroring the row above it.
        Row(
          children: days
              .map(
                (day) => Expanded(
                  child: Text(
                    day.label,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _bar(DayAttendanceRate day) {
    final rate = day.rate;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          Text(
            rate == null ? '—' : '$rate%',
            style: AppTextStyles.caption.copyWith(
              color: rate == null ? AppColors.outline : AppColors.primary,
            ),
          ),
          SizedBox(height: 4.h),
          // The track is drawn whether or not there is a figure to fill it, so
          // an unmarked day reads as an empty column instead of vanishing into
          // the baseline the way a 0% bar would.
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.outlineVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(4.r),
                ),
              ),
              child: FractionallySizedBox(
                heightFactor: (rate ?? 0) / 100,
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(4.r),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
