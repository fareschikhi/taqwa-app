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
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/halaqa_news_card.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/shared/presentation/pages/halaqa_news_page.dart';
import 'package:taqwa/features/manager/presentation/widgets/delete_halaqa_news.dart';
import 'package:taqwa/features/manager/presentation/widgets/halaqa_news_form_sheet.dart';

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
  final _newsRepo = HalaqaAnnouncementRepository();
  bool _isLoading = true;
  int _studentsCount = 0;
  int _teachersCount = 0;
  int _halaqasCount = 0;
  int _managersCount = 0;
  List<HalaqaAnnouncementModel> _news = [];

  /// Students marked present today over everyone marked at all, as a count.
  /// Em dash until the first record of the day lands.
  String _attendanceToday = '—';
  List<DayAttendance> _week = const [];

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

      // A failed feed must not cost the dashboard the data it already has, so
      // it degrades to an empty list rather than throwing — the same call
      // ParentShell._loadUnread makes for its badge.
      final news = await _newsRepo.myAnnouncements().catchError(
        (_) => <HalaqaAnnouncementModel>[],
      );

      // Compute today's attendance from today's records
      String attendedToday = '—';
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
          attendedToday = '$present من ${attList.length}';
        }
      } catch (_) {}

      // The weekly chart is a nicety: if it fails the rest of the dashboard
      // still loads, and the chart says it has nothing rather than inventing
      // a week.
      List<DayAttendance> week = const [];
      try {
        week = weeklyAttendanceFrom(
          await _teacherRepo.getWeeklyAttendanceRates(),
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _studentsCount = studentsCount;
          _teachersCount = teachers.length;
          _halaqasCount = halaqas.length;
          _managersCount = managers.length;
          _attendanceToday = attendedToday;
          _week = week;
          _news = news;
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
                    HalaqaNewsCard(
                      announcements: _news,
                      canCompose: true,
                      onCompose: _composeNews,
                      onEdit: (a) => _composeNews(existing: a),
                      onDelete: _deleteNews,
                      onSeeAll: _openNews,
                    ),
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

  Future<void> _composeNews({HalaqaAnnouncementModel? existing}) async {
    final saved = await HalaqaNewsFormSheet.show(
      context,
      isAdmin: true,
      existing: existing,
    );
    if (saved) await _loadStats();
  }

  Future<void> _deleteNews(HalaqaAnnouncementModel announcement) async {
    if (await deleteHalaqaNews(context, announcement)) await _loadStats();
  }

  Future<void> _openNews() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const HalaqaNewsPage(canCompose: true, isAdmin: true),
      ),
    );
    await _loadStats();
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
            AppText(
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
        AppText(
          'مرحباً بك، $name',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.primary,
          ),
        ),
        SizedBox(height: 4.h),
        AppText(
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
          value: _attendanceToday,
          label: 'الحضور اليوم',
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
                child: AppText(
                  'هذا الأسبوع',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.secondary,
                  ),
                ),
              ),
              const Spacer(),
              AppText(
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
                child: AppText(
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

  final List<DayAttendance> days;

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
                  child: AppText(
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

  Widget _bar(DayAttendance day) {
    final marked = day.marked;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          AppText(
            day.hasRecord ? '${day.present}' : '—',
            // labelSm, not caption: this is a head count the admin has to
            // actually read, and 10sp Tajawal reads as decoration.
            style: AppTextStyles.labelSm.copyWith(
              color: day.hasRecord ? AppColors.primary : AppColors.outline,
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
                heightFactor: marked > 0 ? day.present / marked : 0,
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
