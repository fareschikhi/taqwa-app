import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';

/// A points total at a glance, built like [FineBalanceCard] so the two sit
/// side by side as one family: header, a coloured pill, then a taste of the
/// history, with [onTap] leading to the rest of it.
class PointsBalanceCard extends StatelessWidget {
  const PointsBalanceCard({
    super.key,
    required this.summary,
    this.title = 'النقاط',
    this.onTap,
  });

  final PointsSummaryModel summary;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final recent = summary.entries.take(3).toList();

    return AppCard(
      padding: EdgeInsets.all(16.w),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              Icon(
                Icons.chevron_left,
                color: AppColors.onSurfaceVariant,
                size: 20.w,
              ),
              const Spacer(),
              AppText(
                title,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _TotalPill(total: summary.total),
          if (recent.isNotEmpty) ...[
            SizedBox(height: 16.h),
            Container(height: 1, color: AppColors.outlineVariant),
            SizedBox(height: 12.h),
            ...recent.map(_buildEntry),
          ],
        ],
      ),
    );
  }

  Widget _buildEntry(PointEntryModel entry) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          AppText(
            formatSignedPoints(entry.amount),
            style: AppTextStyles.labelMdBold.copyWith(
              color: pointsColor(entry.amount),
            ),
          ),
          SizedBox(width: 12.w),
          // A manual reason is free text: let it shorten, never push the
          // amount off the card.
          Expanded(
            child: AppText(
              entry.label,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gains in the brand colour, losses in the error colour. Zero counts as a
/// gain: nothing has been lost.
Color pointsColor(num value) => value < 0 ? AppColors.error : AppColors.primary;

class _TotalPill extends StatelessWidget {
  const _TotalPill({required this.total});

  final num total;

  @override
  Widget build(BuildContext context) {
    final color = pointsColor(total);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: AppText(
        formatPoints(total),
        style: AppTextStyles.headlineSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
