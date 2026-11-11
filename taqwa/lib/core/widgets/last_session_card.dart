import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/enums/memorization_subject.dart';
import 'package:taqwa/core/enums/memorization_type.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/last_session.dart';
import 'package:taqwa/core/utils/hadith_label.dart'
    show hadithLabelOrFallback, entryAmountText;
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/utils/memorization_amount.dart';

/// The last day the child was marked, and what they recited on it.
///
/// A parent opening the app asks "how did it go last time", which a running
/// percentage cannot answer. [session] is null until any attendance exists.
class LastSessionCard extends StatelessWidget {
  const LastSessionCard({super.key, required this.session});

  final LastSession? session;

  @override
  Widget build(BuildContext context) {
    final session = this.session;

    if (session == null) {
      return AppCard(
        padding: EdgeInsets.all(16.w),
        child: Align(
          alignment: Alignment.centerRight,
          child: AppText(
            'لا يوجد سجل حضور بعد',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // The same split the attendance history reads, so a parent who moves
    // between the two screens sees one vocabulary.
    final (label, color, icon) = switch (session.status) {
      'PRESENT' => ('حاضر', AppColors.present, Icons.check),
      'LATE' => ('متأخر', AppColors.late, Icons.schedule),
      'EXCUSED' => ('عذر', AppColors.excused, Icons.event_busy_outlined),
      _ => ('غائب', AppColors.absent, Icons.close),
    };

    final date = session.date;
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
              _StatusPill(label: label, color: color, icon: icon),
              const Spacer(),
              AppText(
                dateText,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12.h),
            child: const Divider(color: AppColors.cardBorder),
          ),
          if (session.entries.isEmpty)
            AppText(
              'لم يُسجل حفظ في هذا اليوم',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            )
          else
            ...session.entries.map(_buildEntry),
        ],
      ),
    );
  }

  Widget _buildEntry(LastSessionEntry entry) {
    final type = entry.type;
    final isHadith = entry.subject == MemorizationSubject.hadith;
    final amount = entryAmountText(
      amount: entry.amount,
      isHadith: isHadith,
      // Older rows carry no unit; countsPages still says which a hadith was.
      unit: entry.unit ?? (isHadith && entry.countsPages ? 'PAGE' : null),
      ayahFrom: entry.ayahFrom,
      ayahTo: entry.ayahTo,
    );

    // A type this build does not know about still happened, so the amount is
    // reported without claiming a unit for it.
    final amountText = type == null
        ? 'تسميع · ${formatAmount(entry.amount)}'
        : '${type.label} · $amount';

    final referenceText = isHadith
        ? hadithLabelOrFallback(entry.hadithReference)
        : 'سورة ${entry.surahName ?? 'رقم ${entry.surahNumber}'}';

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  amountText,
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.end,
                ),
                AppText(
                  referenceText,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          Icon(
            isHadith ? Icons.auto_stories_outlined : Icons.menu_book_outlined,
            size: 22.w,
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppText(
            label,
            style: AppTextStyles.labelMdBold.copyWith(color: color),
          ),
          SizedBox(width: 6.w),
          Icon(icon, size: 16.w, color: color),
        ],
      ),
    );
  }
}
