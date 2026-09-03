import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/enums/memorization_subject.dart';
import 'package:taqwa/core/enums/memorization_type.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/last_session.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';

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

    // The same three-way split the attendance history reads, so a parent who
    // moves between the two screens sees one vocabulary.
    final (label, color, icon) = switch (session.status) {
      'PRESENT' => ('حاضر', AppColors.present, Icons.check),
      'LATE' => ('متأخر', AppColors.late, Icons.schedule),
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
              AppText(
                dateText,
                style: AppTextStyles.labelMd.copyWith(color: AppColors.outline),
              ),
              const Spacer(),
              _StatusPill(label: label, color: color, icon: icon),
            ],
          ),
          SizedBox(height: 12.h),
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

    // A type this build does not know about still happened, so the amount is
    // reported without claiming a unit for it.
    final amountText = type == null
        ? 'تسميع · ${entry.amount}'
        : '${type.label} · ${entry.amount} ${isHadith ? 'حديث' : type.unitLabel}';

    final referenceText = isHadith
        ? ((entry.hadithReference?.trim().isNotEmpty ?? false)
            ? entry.hadithReference!
            : 'حديث')
        : 'سورة ${entry.surahName ?? 'رقم ${entry.surahNumber}'}';

    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            amountText,
            style: AppTextStyles.labelMdBold.copyWith(
              color: AppColors.onSurface,
            ),
            textAlign: TextAlign.end,
          ),
          AppText(
            referenceText,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.end,
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
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppConstants.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: color),
          SizedBox(width: 4.w),
          AppText(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
