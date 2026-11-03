import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/data/models/points/point_entry_model.dart';
import 'package:taqwa/features/data/models/points/points_summary_model.dart';

/// Every entry behind a points total. [summary] is passed in rather than
/// reloaded, as on the fines statement, so the list always agrees with the
/// total that was just tapped.
class PointsHistoryPage extends StatelessWidget {
  const PointsHistoryPage({
    super.key,
    required this.summary,
    this.title = 'سجل النقاط',
  });

  final PointsSummaryModel summary;
  final String title;

  @override
  Widget build(BuildContext context) {
    final entries = summary.entries;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: AppText(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        iconTheme: const IconThemeData(color: AppColors.onSurface),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Align(
                alignment: Alignment.centerRight,
                child: AppText(
                  'المجموع: ${formatPoints(summary.total)}',
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: AppText(
                        'لا توجد نقاط مسجلة بعد',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => SizedBox(height: 8.h),
                      itemBuilder: (_, i) => _buildEntry(entries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(PointEntryModel entry) {
    final date = entry.displayDate;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
    final by = entry.createdByName;

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              AppText(
                formatSignedPoints(entry.amount),
                style: AppTextStyles.labelMdBold.copyWith(
                  color: pointsColor(entry.amount),
                ),
              ),
              const Spacer(),
              Flexible(
                child: AppText(
                  entry.label,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          AppText(
            dateText,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.outline),
          ),
          if (by != null && by.isNotEmpty) ...[
            SizedBox(height: 2.h),
            AppText(
              'بواسطة $by',
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
