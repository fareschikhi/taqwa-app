import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';

/// A student's points total on his roster card, styled like the fine-balance
/// chip beside it so the two read as a pair.
class PointsChip extends StatelessWidget {
  const PointsChip({super.key, required this.points});

  final num points;

  @override
  Widget build(BuildContext context) {
    final color = pointsColor(points);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: AppText(
        formatPoints(points),
        style: AppTextStyles.labelMd.copyWith(color: color),
      ),
    );
  }
}
