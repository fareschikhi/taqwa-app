import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/progress_card.dart';

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({super.key, required this.student});
  final String student;

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {},
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  SizedBox(height: 20.h),
                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'نسبة الحفظ',
                          value: '85%',
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _StatBox(
                          label: 'الحضور',
                          value: '92%',
                          color: AppColors.secondary,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _StatBox(
                          label: 'التقييم العام',
                          value: 'ممتاز',
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20.h),
                  // Current task
                  AppCard(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'المهمة الحالية',
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'حفظ سورة البقرة',
                                    style: AppTextStyles.bodyMdBold.copyWith(
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'من الآية 100 إلى الآية 150',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusFull,
                                    ),
                                    child: LinearProgressIndicator(
                                      value: 0.65,
                                      minHeight: 10.h,
                                      backgroundColor:
                                          AppColors.surfaceContainerHigh,
                                      valueColor: const AlwaysStoppedAnimation(
                                        AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Align(
                                    alignment: AlignmentDirectional.centerStart,
                                    child: Text(
                                      '65%',
                                      style: AppTextStyles.labelMdBold.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 20.w),
                            CircularProgressWidget(
                              percentage: 0.65,
                              label: 'الإنجاز',
                              size: 80.w,
                              strokeWidth: 8.w,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  // Memorization history
                  AppCard(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'سجل الحفظ والمراجعة',
                          style: AppTextStyles.headlineSm.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        _RecordItem(
                          date: '11/06',
                          surah: 'سورة البقرة (100-115)',
                          type: 'حفظ جديد',
                          score: 'ممتاز',
                        ),
                        _RecordItem(
                          date: '09/06',
                          surah: 'سورة آل عمران (1-50)',
                          type: 'مراجعة',
                          score: 'جيد جداً',
                        ),
                        _RecordItem(
                          date: '07/06',
                          surah: 'سورة البقرة (85-100)',
                          type: 'حفظ جديد',
                          score: 'ممتاز',
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildHeader(BuildContext context) {
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                    ),
                    child: Text(
                      'مبتدئ - المستوى 3',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'حلقة النور',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                  Text(
                    'المعلم: أ. أحمد',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onPrimary.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 64.w,
                    height: 64.w,
                    decoration: BoxDecoration(
                      color: AppColors.onPrimary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.onPrimary.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'ع',
                        style: AppTextStyles.headlineLgMobile.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    widget.student,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimary,
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

class _StatBox extends StatelessWidget {
  const _StatBox({
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

class _RecordItem extends StatelessWidget {
  const _RecordItem({
    required this.date,
    required this.surah,
    required this.type,
    required this.score,
  });
  final String date, surah, type, score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: Text(
              score,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                surah,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  Text(
                    date,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 6.w,
                      vertical: 2.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusFull,
                      ),
                    ),
                    child: Text(
                      type,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Container(
            width: 8.w,
            height: 8.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
