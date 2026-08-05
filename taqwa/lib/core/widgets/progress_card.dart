import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'app_card.dart';

/// Progress bar card (linear or circular)
class ProgressCard extends StatelessWidget {
  const ProgressCard({
    super.key,
    required this.title,
    required this.value,
    required this.percentage,
    this.color,
    this.onTap,
    this.subtitle,
  });

  final String title;
  final String value;
  final double percentage;
  final Color? color;
  final VoidCallback? onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final barColor = color ?? AppColors.primary;
    return AppCard(
      padding: EdgeInsets.all(20.w),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value,
                style: AppTextStyles.headlineMd.copyWith(color: barColor),
              ),
              Text(
                title,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: 4.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                subtitle!,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
          SizedBox(height: 12.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 8.h,
              backgroundColor: AppColors.surfaceContainerHigh,
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular progress widget
class CircularProgressWidget extends StatelessWidget {
  const CircularProgressWidget({
    super.key,
    required this.percentage,
    required this.label,
    this.size,
    this.strokeWidth,
    this.color,
    this.centerText,
  });

  final double percentage;
  final String label;
  final double? size;
  final double? strokeWidth;
  final Color? color;
  final String? centerText;

  @override
  Widget build(BuildContext context) {
    final sz = size ?? 120.w;
    final sw = strokeWidth ?? 10.w;
    final color0 = color ?? AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: sz,
          height: sz,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: sz,
                height: sz,
                child: CircularProgressIndicator(
                  value: percentage.clamp(0.0, 1.0),
                  strokeWidth: sw,
                  backgroundColor: AppColors.surfaceContainerHigh,
                  valueColor: AlwaysStoppedAnimation(color0),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerText ?? '${(percentage * 100).round()}%',
                    style: AppTextStyles.headlineMd.copyWith(
                      color: color0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

