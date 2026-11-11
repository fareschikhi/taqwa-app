import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/memorization_amount.dart';
import 'package:taqwa/core/utils/progress_totals.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// One subject's memorized totals — Quran or hadith — as a tile per unit the
/// student is actually counted in: «12 صفحة» beside «40 آية», or «4 حديث»
/// beside «2 صفحة». The units are different quantities, so each keeps its own
/// tile and they are never summed.
class MemorizationTotalsCard extends StatelessWidget {
  const MemorizationTotalsCard({
    super.key,
    required this.title,
    required this.icon,
    required this.totals,
    this.subtitle,
    this.onTap,
  });

  final String title;
  final IconData icon;

  /// Already filtered by [quranTotals] / [hadithTotals]: never empty.
  final List<UnitTotal> totals;

  /// A line under the tiles, e.g. how many surahs were touched.
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppText(
                title,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(icon, size: 18.w, color: AppColors.primary),
            ],
          ),
          SizedBox(height: 12.h),
          // Reading order is right to left, so the first unit goes last in
          // this left-to-right row.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, total) in totals.reversed.indexed) ...[
                  if (i > 0) SizedBox(width: 12.w),
                  Expanded(child: _UnitTile(total: total)),
                ],
              ],
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 10.h),
            AppText(
              subtitle!,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UnitTile extends StatelessWidget {
  const _UnitTile({required this.total});
  final UnitTotal total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AppText(
            formatAmount(total.value),
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 2.h),
          AppText(
            total.unit,
            textAlign: TextAlign.center,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
