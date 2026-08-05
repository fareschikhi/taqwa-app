import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/attendance_summary_model.dart';
import '../../../data/models/parent/parent_child_model.dart';
import 'child_details_page.dart';

class ParentDashboardPage extends ConsumerStatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  ConsumerState<ParentDashboardPage> createState() =>
      _ParentDashboardPageState();
}

class _ParentDashboardPageState extends ConsumerState<ParentDashboardPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  AttendanceSummaryModel? _attendance;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _notes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(selectedChildProvider).selected?.id;
      if (id != null) _load(id);
    });
  }

  Future<void> _load(int childId) async {
    setState(() {
      _isLoading = true;
      _loadedChildId = childId;
    });
    try {
      final results = await Future.wait([
        _repo.getAttendanceSummary(childId),
        _repo.getMemorizationProgress(childId),
        _repo.getProfile(childId),
      ]);
      final profile = results[2] as Map<String, dynamic>;
      final rawNotes = (profile['notes'] as List?) ?? [];
      if (mounted) {
        setState(() {
          _attendance = results[0] as AttendanceSummaryModel;
          _progress = results[1] as Map<String, dynamic>;
          _notes = rawNotes.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(selectedChildProvider);
    final child = childState.selected;
    final parentName = ref.watch(authProvider).user?.fullName ?? '';

    ref.listen(selectedChildProvider, (previous, next) {
      final id = next.selected?.id;
      if (id != null && id != _loadedChildId) _load(id);
    });

    if (child == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 20.h),
                    _buildGreeting(parentName),
                    SizedBox(height: 24.h),
                    _buildChildCard(context, child),
                    SizedBox(height: 20.h),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      _buildQuickStats(),
                      SizedBox(height: 20.h),
                      _buildTeacherNotes(),
                    ],
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
            Container(
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
            const Spacer(),
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: AppColors.onPrimaryContainer,
                size: 20.w,
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
    );
  }

  Widget _buildGreeting(String parentName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          parentName.isNotEmpty ? 'أهلاً، $parentName' : 'أهلاً بك',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.onBackground,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          'تابع تقدم أبنائك في حفظ القرآن الكريم.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildChildCard(BuildContext context, ParentChildModel child) {
    final attendanceRate = _attendance?.rate ?? 0;
    final pagesDone = (_progress?['totalPagesDone'] as num?)?.toInt() ?? 0;
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final reviewCount =
        ((typeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0) +
        ((typeCounts['BIGREVISION'] as num?)?.toInt() ?? 0);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChildDetailsPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primary, AppColors.secondary],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'عرض التفاصيل',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.onPrimary,
                      size: 16,
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      child.fullName,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      child.halaqaName ?? 'غير مسجل في حلقة',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                AvatarWidget(
                  avatarUrl: child.avatar,
                  size: 56.w,
                  backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
                  fallback: Text(
                    child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                    style: AppTextStyles.headlineMd.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'حضور',
                      value: _isLoading ? '--' : '$attendanceRate%',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _StatChip(
                      label: 'حفظ',
                      value: _isLoading ? '--' : '$pagesDone صفحة',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _StatChip(
                      label: 'مراجعة',
                      value: _isLoading ? '--' : '$reviewCount مرة',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats() {
    final totalSurahs = (_progress?['totalSurahs'] as num?)?.toInt() ?? 0;
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final newCount = (typeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'تقدم الحفظ',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'سور تم تناولها',
                value: '$totalSurahs',
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _StatCard(
                title: 'جلسات حفظ جديد',
                value: '$newCount',
                color: AppColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTeacherNotes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'ملاحظات المعلم',
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onSurface,
          ),
        ),
        SizedBox(height: 12.h),
        if (_notes.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: Text(
              'لا توجد ملاحظات بعد',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          ..._notes.map((n) {
            String displayDate = '';
            try {
              final dt = DateTime.parse(n['createdAt'] as String);
              displayDate = '${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {
              displayDate = (n['createdAt'] ?? '').toString();
            }
            final teacherName =
                (n['teacher'] as Map<String, dynamic>?)?['user']
                        as Map<String, dynamic>? ??
                {};

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: AppCard(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Text(
                          displayDate,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          (teacherName['fullName'] as String?) ?? '',
                          style: AppTextStyles.labelMdBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      (n['note'] as String?) ?? '',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });
  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            value,
            style: AppTextStyles.headlineMd.copyWith(color: color),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        value,
        style: AppTextStyles.headlineSm.copyWith(
          color: AppColors.onPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      Text(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onPrimary.withValues(alpha: 0.8),
        ),
      ),
    ],
  );
}
