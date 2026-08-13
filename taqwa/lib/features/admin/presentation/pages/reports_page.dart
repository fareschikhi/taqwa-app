import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/widgets/app_card.dart';
import '../admin_shell.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _periodIndex = 1;
  final _periods = ['هذا الأسبوع', 'هذا الشهر', 'هذا العام'];

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
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16.h),
                    // Header
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => AdminShellScope.of(context)?.openMenu(),
                          child: Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMd,
                              ),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 6.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer.withValues(
                              alpha: 0.3,
                            ),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusFull,
                            ),
                            border: Border.all(color: AppColors.outlineVariant),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'التقارير والإحصاءات',
                          style: AppTextStyles.headlineLgMobile.copyWith(
                            color: AppColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        'تتبع أداء المعهد بشكل دوري',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Period filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true,
                      child: Row(
                        children: List.generate(_periods.length, (i) {
                          final selected = _periodIndex == i;
                          return Padding(
                            padding: EdgeInsets.only(left: 8.w),
                            child: GestureDetector(
                              onTap: () => setState(() => _periodIndex = i),
                              child: AnimatedContainer(
                                duration: AppConstants.animFast,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusFull,
                                  ),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.outlineVariant,
                                  ),
                                ),
                                child: Text(
                                  _periods[i],
                                  style: AppTextStyles.labelMd.copyWith(
                                    color: selected
                                        ? AppColors.onPrimary
                                        : AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    // KPI row
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        childAspectRatio: 1.6,
                      ),
                      children: [
                        StatCard(
                          value: '1,240',
                          label: 'إجمالي الطلاب',
                          icon: Icons.group,
                          trend: '5.2%+',
                          trendPositive: true,
                        ),
                        StatCard(
                          value: '94%',
                          label: 'نسبة الحضور',
                          icon: Icons.check_circle,
                          valueColor: AppColors.primary,
                          iconColor: AppColors.primary,
                          iconBgColor: AppColors.primaryContainer,
                          bubbleColor: AppColors.primaryContainer,
                        ),
                        StatCard(
                          value: '82',
                          label: 'الحلقات النشطة',
                          icon: Icons.menu_book,
                          iconColor: AppColors.tertiary,
                          iconBgColor: AppColors.tertiaryContainer,
                          bubbleColor: AppColors.tertiaryContainer,
                        ),
                        StatCard(
                          value: '14',
                          label: 'طلاب متأخرون',
                          icon: Icons.warning_amber_outlined,
                          iconColor: AppColors.error,
                          iconBgColor: AppColors.errorContainer,
                          bubbleColor: AppColors.errorContainer,
                          valueColor: AppColors.error,
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    // Memorization completion
                    AppCard(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'إتمام الحفظ',
                            style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'نسبة الطلاب الذين أتموا أهداف الحفظ هذا الشهر',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.end,
                          ),
                          SizedBox(height: 20.h),
                          Center(child: _DonutChart(percentage: 0.65)),
                          SizedBox(height: 20.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _LegendItem(
                                color: AppColors.primary,
                                label: 'أتمّوا الهدف',
                                value: '65%',
                              ),
                              _LegendItem(
                                color: AppColors.surfaceContainerHigh,
                                label: 'لم يتموا الهدف',
                                value: '35%',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Teacher performance
                    AppCard(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'أداء المعلمين',
                            style: AppTextStyles.headlineSm.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                          SizedBox(height: 16.h),
                          _TeacherPerfRow(name: 'الشيخ محمود', score: 0.92),
                          SizedBox(height: 12.h),
                          _TeacherPerfRow(name: 'الشيخ يوسف', score: 0.88),
                          SizedBox(height: 12.h),
                          _TeacherPerfRow(name: 'الشيخ أحمد', score: 0.78),
                          SizedBox(height: 12.h),
                          _TeacherPerfRow(
                            name: 'الشيخ عبدالله',
                            score: 0.65,
                            color: AppColors.secondary,
                          ),
                        ],
                      ),
                    ),
                    // Weekly Attendance Chart
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
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.percentage});
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140.w,
      height: 140.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 140.w,
            height: 140.w,
            child: CircularProgressIndicator(
              value: percentage,
              strokeWidth: 20.w,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentage * 100).round()}%',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'إتمام',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
  });
  final Color color;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppTextStyles.labelMdBold.copyWith(color: color)),
        SizedBox(width: 4.w),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(width: 6.w),
        Container(
          width: 12.w,
          height: 12.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ],
    );
  }
}

class _TeacherPerfRow extends StatelessWidget {
  const _TeacherPerfRow({required this.name, required this.score, this.color});
  final String name;
  final double score;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    return Row(
      children: [
        Text(
          '${(score * 100).round()}%',
          style: AppTextStyles.labelMdBold.copyWith(color: barColor),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: score,
              minHeight: 8.h,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
        SizedBox(width: 8.w),
        SizedBox(
          width: 80.w,
          child: Text(
            name,
            style: AppTextStyles.labelSm.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
