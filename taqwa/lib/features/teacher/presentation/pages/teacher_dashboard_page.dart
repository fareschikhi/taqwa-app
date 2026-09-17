import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/progress_card.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/attendance_summary_model.dart';
import '../../../data/models/revision_needed_model.dart';
import '../../../data/models/memorization_progress_summary_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class TeacherDashboardPage extends ConsumerStatefulWidget {
  const TeacherDashboardPage({super.key});

  @override
  ConsumerState<TeacherDashboardPage> createState() =>
      _TeacherDashboardPageState();
}

class _TeacherDashboardPageState extends ConsumerState<TeacherDashboardPage> {
  final _repo = TeacherRepository();

  AttendanceSummaryModel? _attendanceSummary;
  List<RevisionNeededModel> _revisionNeeded = [];
  MemorizationProgressSummaryModel? _memorizationProgress;

  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Defer so authProvider is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> loadData() async {
    final user = ref.read(authProvider).user;
    final teacherId = user?.teacherId;
    if (teacherId == null) {
      setState(() {
        _isLoading = false;
        _error = 'لم يتم العثور على معرف المعلم';
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getAttendanceSummary(teacherId),
        _repo.getRevisionNeeded(teacherId),
        _repo.getMemorizationProgress(teacherId),
      ]);
      setState(() {
        _attendanceSummary = results[0] as AttendanceSummaryModel;
        _revisionNeeded = results[1] as List<RevisionNeededModel>;
        _memorizationProgress = results[2] as MemorizationProgressSummaryModel;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'حدث خطأ أثناء تحميل البيانات';
      });
    }
  }

  Future<void> _loadData() => loadData();

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null &&
          (_error != null || _attendanceSummary == null)) {
        _loadData();
      }
    });

    final user = ref.watch(authProvider).user;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _error != null
            ? RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Container(
                    height: MediaQuery.of(context).size.height * 0.7,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          _error!,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: const AppText('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          SizedBox(height: 24.h),
                          _buildGreeting(user?.fullName),
                          SizedBox(height: 24.h),
                          _buildBentoGrid(),
                          SizedBox(height: 24.h),
                          _buildMemorizationProgress(),
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

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56.h,
      flexibleSpace: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            GestureDetector(
              onTap: () {},
              child: Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            const Spacer(),
            AppText(
              'تقوى',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(String? name) {
    final greeting = name != null ? 'مرحباً بك، أ. $name' : 'مرحباً بك';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          greeting,
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.onBackground,
          ),
        ),
        SizedBox(height: 4.h),
        AppText(
          'يوم مبارك للتعليم والمراجعة.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBentoGrid() {
    // This endpoint scopes `present` and `absent` to the current month and has
    // already folded late arrivals into `present`, so these are the days the
    // halaqa was attended this month rather than over the whole enrolment.
    final attendedDays = _attendanceSummary?.present ?? 0;
    final markedDays = attendedDays + (_attendanceSummary?.absent ?? 0);
    return Column(
      children: [
        // Attendance summary — full width, horizontal layout
        AppCard(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 20.h),
          child: Row(
            children: [
              // Stats
              Expanded(
                child: CircularProgressWidget(
                  // The ring stays a visual; the figure inside it is the
                  // number of days, which is what the teacher is being told.
                  fillFraction: markedDays > 0 ? attendedDays / markedDays : 0.0,
                  centerText: '$attendedDays',
                  label: 'أيام الحضور هذا الشهر',
                  size: 80.w,
                  strokeWidth: 8.w,
                ),
              ),
              SizedBox(width: 12.w),
              // Circular progress + title
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AppText(
                    'ملخص الحضور',
                    style: AppTextStyles.labelMdBold.copyWith(
                      color: AppColors.onBackground,
                    ),
                  ),
                  SizedBox(height: 12.w),
                  Row(
                    children: [
                      Column(
                        children: [
                          AppText(
                            '${_attendanceSummary?.present ?? 0}',
                            style: AppTextStyles.bodyLg.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.onBackground,
                            ),
                          ),
                          SizedBox(width: 48.w),
                          AppText(
                            'حاضر',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          AppText(
                            '${_attendanceSummary?.absent ?? 0}',
                            style: AppTextStyles.bodyLg.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                          AppText(
                            'غائب',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 8.h),
            ],
          ),
        ),
        SizedBox(height: 12.h),
        // Students needing review — full width
        AppCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                'طلاب يحتاجون مراجعة',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              SizedBox(height: 12.h),
              if (_revisionNeeded.isEmpty)
                AppText(
                  'جميع الطلاب بخير 🎉',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                )
              else
                ..._revisionNeeded.take(5).toList().asMap().entries.map((
                  entry,
                ) {
                  final student = entry.value;
                  final colors = [
                    AppColors.primaryContainer,
                    AppColors.tertiaryContainer,
                    AppColors.secondaryContainer,
                  ];
                  final color = colors[entry.key % colors.length];
                  final initial = student.name.isNotEmpty
                      ? student.name[0]
                      : '؟';
                  return Column(
                    children: [
                      _ReviewStudentRow(
                        name: student.name,
                        issue:
                            '${student.daysWithoutMemorization} :ايام بدون عرض',
                        initial: initial,
                        bgColor: color,
                      ),
                      if (entry.key < _revisionNeeded.take(5).length - 1)
                        SizedBox(height: 8.h),
                    ],
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMemorizationProgress() {
    final mem = _memorizationProgress;
    return AppCard(
      padding: EdgeInsets.all(20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            'تقدم الحفظ ',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onBackground,
            ),
          ),
          SizedBox(height: 16.h),
          _ProgressBarRow(
            label: 'الحفظ',
            count: mem?.memorizingCount ?? 0,
            total: mem?.studentsCount ?? 0,
            color: AppColors.primary,
          ),
          SizedBox(height: 12.h),
          _ProgressBarRow(
            label: 'مراجعة صغرى',
            count: mem?.minorReviewCount ?? 0,
            total: mem?.studentsCount ?? 0,
            color: AppColors.secondary,
          ),
          SizedBox(height: 12.h),
          _ProgressBarRow(
            label: 'مراجعة كبرى',
            count: mem?.majorReviewCount ?? 0,
            total: mem?.studentsCount ?? 0,
            color: AppColors.tertiary,
          ),
        ],
      ),
    );
  }
}

class _ReviewStudentRow extends StatelessWidget {
  const _ReviewStudentRow({
    required this.name,
    required this.issue,
    required this.initial,
    required this.bgColor,
  });
  final String name, issue, initial;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: () {},
          child: Container(
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.edit_note,
              color: AppColors.primary,
              size: 20,
            ),
          ),
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            AppText(
              name,
              style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w500,
                color: AppColors.onBackground,
              ),
            ),
            AppText(
              issue,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
            ),
          ],
        ),
        SizedBox(width: 12.w),
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Center(
            child: AppText(
              initial,
              style: AppTextStyles.bodyMdBold.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressBarRow extends StatelessWidget {
  const _ProgressBarRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });
  final String label;

  /// Students at this stage, and everyone the bar measures them against.
  final int count;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // The bar is a visual only; the figure beside it is the head count, so an
    // empty halaqa draws an empty track rather than dividing by zero.
    final fill = total > 0 ? count / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(
              '$count من $total',
              style: AppTextStyles.labelMdBold.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
            AppText(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onBackground,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          child: LinearProgressIndicator(
            value: fill,
            minHeight: 8.h,
            backgroundColor: AppColors.surfaceContainerHigh,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
