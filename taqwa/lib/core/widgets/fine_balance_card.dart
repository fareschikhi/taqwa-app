import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/fine_balance.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/models/fine/fine_entry_model.dart';
import 'package:taqwa/features/data/models/fine/fine_summary_model.dart';

/// What a student owes, at a glance. This is the balance's only home on his
/// dashboard — there is no separate tab for it — so the number has to carry
/// the whole story and [onTap] has to lead somewhere with the rest of it.
class FineBalanceCard extends StatelessWidget {
  const FineBalanceCard({super.key, required this.summary, this.onTap});

  final FineSummaryModel summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final balance = displayedBalance(summary.balance);
    final cleared = balance == 0;

    // Newest first, and only a taste of the statement — the tap target
    // beneath the balance is what leads to the rest of it.
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
                'الرصيد المستحق',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _BalancePill(text: formatFine(balance), cleared: cleared),
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

  Widget _buildEntry(FineEntryModel entry) {
    final isCharge = entry.kind == 'CHARGE';
    final sign = isCharge ? '+' : '-';
    final color = isCharge ? AppColors.error : AppColors.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          AppText(
            '$sign ${formatFine(entry.amount)}',
            style: AppTextStyles.labelMdBold.copyWith(color: color),
          ),
          const Spacer(),
          AppText(
            entry.label,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors the status pill on `LastSessionCard`: a colored badge is what a
/// parent's attendance card leads with, and a balance deserves the same
/// weight rather than plain body text sitting loose in the card.
class _BalancePill extends StatelessWidget {
  const _BalancePill({required this.text, required this.cleared});

  final String text;
  final bool cleared;

  @override
  Widget build(BuildContext context) {
    final color = cleared ? AppColors.primary : AppColors.error;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: AppText(
        text,
        style: AppTextStyles.headlineSm.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
