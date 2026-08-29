import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_text.dart';

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
                  AppText(
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
        AppText(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

