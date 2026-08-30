import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/fine_balance.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/models/fine/fine_entry_model.dart';
import 'package:taqwa/features/data/models/fine/fine_summary_model.dart';

/// Every entry behind the balance card's number, in full. `summary` is
/// passed in rather than reloaded, so the list on screen always matches the
/// balance the student just tapped — a second request landing between the
/// two could otherwise show a total that no longer agrees with its own rows.
class FinesHistoryPage extends StatelessWidget {
  const FinesHistoryPage({super.key, required this.summary});

  final FineSummaryModel summary;

  @override
  Widget build(BuildContext context) {
    // Newest first: what changed the balance most recently is what a student
    // checking his statement wants to see without scrolling for it.
    final entries = [...summary.entries]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: AppText(
          'سجل الرسوم',
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
                  'الرصيد المستحق: ${formatFine(displayedBalance(summary.balance))}',
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
                        'لا توجد حركات مسجلة',
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

  Widget _buildEntry(FineEntryModel entry) {
    final isCharge = entry.kind == 'CHARGE';
    final sign = isCharge ? '+' : '-';
    final color = isCharge ? AppColors.error : AppColors.primary;
    final date = entry.createdAt;
    final dateText =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              AppText(
                '$sign ${formatFine(entry.amount)}',
                style: AppTextStyles.labelMdBold.copyWith(color: color),
              ),
              const Spacer(),
              AppText(
                entry.label,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          AppText(
            dateText,
            style: AppTextStyles.labelMd.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }
}
