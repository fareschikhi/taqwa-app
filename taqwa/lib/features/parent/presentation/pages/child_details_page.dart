import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/parent/parent_child_model.dart';

class ChildDetailsPage extends ConsumerStatefulWidget {
  const ChildDetailsPage({super.key});

  @override
  ConsumerState<ChildDetailsPage> createState() => _ChildDetailsPageState();
}

class _ChildDetailsPageState extends ConsumerState<ChildDetailsPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

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
        _repo.getProfile(childId),
        _repo.getMemorizationProgress(childId),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0];
          _progress = results[1];
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = ref.watch(selectedChildProvider).selected;

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

    final halaqa = _profile?['halaqa'] as Map<String, dynamic>?;
    final teacherName =
        ((halaqa?['teacher'] as Map<String, dynamic>?)?['user']
                as Map<String, dynamic>?)?['fullName'] as String? ??
        'غير معين';
    final enrollmentDate = _formatDate(_profile?['enrollmentDate']);
    final memorizationList =
        (_profile?['memorization'] as List?)?.cast<Map<String, dynamic>>() ??
        [];
    final evaluations =
        (_profile?['evaluations'] as List?)?.cast<Map<String, dynamic>>() ??
        [];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context, child, halaqa)),
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              label: 'المعلم',
                              value: teacherName,
                              icon: Icons.person_outline,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _InfoBox(
                              label: 'الحلقة',
                              value: (halaqa?['name'] as String?) ?? 'غير مسجل',
                              icon: Icons.menu_book_outlined,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBox(
                              label: 'تاريخ الالتحاق',
                              value: enrollmentDate,
                              icon: Icons.calendar_today_outlined,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _InfoBox(
                              label: 'المستوى',
                              value: (halaqa?['level'] as String?) ?? 'غير محدد',
                              icon: Icons.trending_up,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      _buildMemorizationCard(),
                      SizedBox(height: 16.h),
                      if (memorizationList.isNotEmpty)
                        _buildCurrentTaskCard(memorizationList.first),
                      if (memorizationList.isNotEmpty) SizedBox(height: 16.h),
                      _buildFeedbackCard(evaluations),
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

  Widget _buildMemorizationCard() {
    final totalPagesDone = (_progress?['totalPagesDone'] as num?)?.toInt() ?? 0;
    final totalSurahs = (_progress?['totalSurahs'] as num?)?.toInt() ?? 0;
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final newCount = (typeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;
    final minorCount = (typeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0;
    final majorCount = (typeCounts['BIGREVISION'] as num?)?.toInt() ?? 0;

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'تقدم الحفظ',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: _CountTile(
                  label: 'صفحات منجزة',
                  value: '$totalPagesDone',
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: _CountTile(
                  label: 'سور تم تناولها',
                  value: '$totalSurahs',
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _CountRow(label: 'حفظ جديد', count: newCount, color: AppColors.primary),
          SizedBox(height: 10.h),
          _CountRow(
            label: 'مراجعة صغرى',
            count: minorCount,
            color: AppColors.secondary,
          ),
          SizedBox(height: 10.h),
          _CountRow(
            label: 'مراجعة كبرى',
            count: majorCount,
            color: AppColors.tertiary,
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTaskCard(Map<String, dynamic> entry) {
    final surahNumber = entry['surahNumber'];
    final amountDone = entry['amountDone'];
    // An unrecognised type falls back to new memorization, matching the
    // column default on the server.
    final type =
        MemorizationTypeX.fromApi(entry['memorizationType'] as String?) ??
        MemorizationType.hifz;
    final typeLabel = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
    final recordedAt = _relativeDate(entry['recordedAt'] ?? entry['date']);

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'آخر تسجيل حفظ',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(color: AppColors.primaryContainer),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                  child: Text(
                    typeLabel,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'سورة رقم $surahNumber',
                        style: AppTextStyles.bodyMdBold.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      Text(
                        '$amountDone ${type.unitLabel}',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'آخر تحديث: $recordedAt',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(List<Map<String, dynamic>> evaluations) {
    if (evaluations.isEmpty) {
      return AppCard(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'آخر تقييم من المعلم',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'لا يوجد تقييم بعد',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final latest = evaluations.first;
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'آخر تقييم من المعلم',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 12.h),
          _FeedbackRow(
            label: 'الحفظ',
            score: _scoreToStars(latest['memorizationScore']),
          ),
          SizedBox(height: 8.h),
          _FeedbackRow(
            label: 'التجويد',
            score: _scoreToStars(latest['tajweedScore']),
          ),
          SizedBox(height: 8.h),
          _FeedbackRow(
            label: 'الطلاقة',
            score: _scoreToStars(latest['fluencyScore']),
          ),
          SizedBox(height: 8.h),
          _FeedbackRow(
            label: 'الانضباط',
            score: _scoreToStars(latest['disciplineScore']),
          ),
        ],
      ),
    );
  }

  int _scoreToStars(dynamic score) {
    if (score == null) return 0;
    return (score as num).round().clamp(0, 5);
  }

  String _formatDate(dynamic raw) {
    if (raw == null) return 'غير محدد';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return 'غير محدد';
    }
  }

  String _relativeDate(dynamic raw) {
    if (raw == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(raw.toString());
      final days = DateTime.now().difference(dt).inDays;
      if (days <= 0) return 'اليوم';
      if (days == 1) return 'منذ يوم';
      return 'منذ $days أيام';
    } catch (_) {
      return 'غير معروف';
    }
  }

  Widget _buildHeader(
    BuildContext context,
    ParentChildModel child,
    Map<String, dynamic>? halaqa,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onPrimary,
                ),
              ),
              const Spacer(),
              Text(
                'ملف الطالب',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
                  Text(
                    (halaqa?['name'] as String?) ?? 'غير مسجل في حلقة',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              AvatarWidget(
                avatarUrl: child.avatar,
                size: 64.w,
                backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
                fallback: Text(
                  child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                  style: AppTextStyles.headlineLgMobile.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 4.w),
              Icon(icon, size: 14.w, color: AppColors.primary),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: AppTextStyles.labelMdBold.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
        ],
      ),
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: AppTextStyles.headlineSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Text(
            '$count',
            style: AppTextStyles.labelMdBold.copyWith(color: color),
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.label, required this.score});
  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (i) => Icon(
              i < score ? Icons.star : Icons.star_border,
              color: i < score ? AppColors.warning : AppColors.outlineVariant,
              size: 18.w,
            ),
          ),
        ),
        Text(
          label,
          style: AppTextStyles.labelMdBold.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }
}
