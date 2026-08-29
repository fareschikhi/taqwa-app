import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/providers/selected_child_provider.dart';
import '../../../../core/utils/memorization_history.dart';
import '../../../data/repositories/student_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class ChildProgressPage extends ConsumerStatefulWidget {
  const ChildProgressPage({super.key});

  @override
  ConsumerState<ChildProgressPage> createState() => _ChildProgressPageState();
}

class _ChildProgressPageState extends ConsumerState<ChildProgressPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _history = [];

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
        _repo.getMemorizationProgress(childId),
        _repo.getMemorizationHistory(childId),
      ]);
      if (mounted) {
        setState(() {
          _progress = results[0] as Map<String, dynamic>;
          _history = results[1] as List<Map<String, dynamic>>;
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

    final totalPagesDone = (_progress?['totalPagesDone'] as num?)?.toInt() ?? 0;
    final totalSurahs = (_progress?['totalSurahs'] as num?)?.toInt() ?? 0;
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final newCount = (typeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;
    final minorCount = (typeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0;
    final majorCount = (typeCounts['BIGREVISION'] as num?)?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        const Spacer(),
                        AppText(
                          'تقوى',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16.h),
                    AppText(
                      'تقدم المدرسة القرآنية',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    AppText(
                      'تتبع رحلة ${child.fullName} في حفظ القرآن الكريم.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      // Summary card
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusXl,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  AppText(
                                    '$totalPagesDone',
                                    style: AppTextStyles.headlineLg.copyWith(
                                      color: AppColors.onPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  AppText(
                                    'صفحة منجزة',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.onPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  AppText(
                                    '$totalSurahs سورة تم تناولها',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onPrimary.withValues(
                                        alpha: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 20.w),
                            Container(
                              width: 70.w,
                              height: 70.w,
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.15,
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.menu_book,
                                color: AppColors.onPrimary,
                                size: 36.w,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: _MiniStat(
                              label: 'حفظ جديد',
                              value: '$newCount',
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _MiniStat(
                              label: 'مراجعة صغرى',
                              value: '$minorCount',
                              color: AppColors.secondary,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _MiniStat(
                              label: 'مراجعة كبرى',
                              value: '$majorCount',
                              color: AppColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          AppText(
                            'سجل الحفظ والمراجعة',
                            style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          const Spacer(),
                          // Say the list is trimmed, so an older entry that is
                          // missing does not read as lost data.
                          if (_history.length > kRecentMemorizationLimit)
                            AppText(
                              'آخر $kRecentMemorizationLimit إدخالات',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      if (_history.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: AppText(
                            'لا يوجد سجل حفظ بعد',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        ...recentMemorization(_history).map(_buildRecordItem),
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

  Widget _buildRecordItem(Map<String, dynamic> entry) {
    // An unrecognised type falls back to new memorization, matching the
    // column default on the server.
    final type =
        MemorizationTypeX.fromApi(entry['memorizationType'] as String?) ??
        MemorizationType.hifz;
    final typeLabel = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
    final surahLabel = surahLabelOf((entry['surahNumber'] as num?)?.toInt());
    String dateStr = '';
    try {
      final dt = DateTime.parse(
        (entry['date'] ?? entry['recordedAt']).toString(),
      );
      dateStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      dateStr = '';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: AppText(
              typeLabel,
              style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                surahLabel,
                style: AppTextStyles.bodyMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 4.h),
              Row(
                children: [
                  AppText(
                    dateStr,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 3.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                    ),
                    child: AppText(
                      '${entry['amountDone']} ${type.unitLabel}',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
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
          AppText(
            value,
            style: AppTextStyles.headlineSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          AppText(
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
