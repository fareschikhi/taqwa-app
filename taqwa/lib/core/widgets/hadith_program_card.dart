import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/enums/memorization_type.dart' show kPageUnitLabel;
import 'package:taqwa/core/utils/hadith_label.dart' show kHadithUnitLabel;
import 'package:taqwa/core/utils/memorization_amount.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// The hadith books the admin assigned a student — the same list the
/// teacher's recitation sheet offers — with how many hadiths he has
/// memorised so far. Callers build it only when [books] is non-empty.
class HadithProgramCard extends StatelessWidget {
  const HadithProgramCard({
    super.key,
    required this.books,
    required this.hadithsDone,
    this.hadithPagesDone,
    this.title = 'الحديث الشريف',
    this.onTap,
  });

  final List<String> books;
  final num? hadithsDone;

  /// Hadith memorized counted in pages. A different unit from [hadithsDone],
  /// so the two are shown side by side, never added together.
  final num? hadithPagesDone;
  final String title;
  final VoidCallback? onTap;

  /// "4 حديث · 2.5 صفحة محفوظ". A unit with nothing in it is left out, but
  /// with nothing at all the card still says "0 حديث".
  String get _doneText {
    final hadiths = hadithsDone ?? 0;
    final pages = hadithPagesDone ?? 0;
    final parts = [
      if (hadiths > 0 || pages <= 0)
        '${formatAmount(hadiths)} $kHadithUnitLabel',
      if (pages > 0) '${formatAmount(pages)} $kPageUnitLabel',
    ];
    return '${parts.join(' · ')} محفوظ';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hadiths and pages together can outgrow one line on a phone:
              // the count wraps, the title keeps its place.
              Expanded(
                child: AppText(
                  _doneText,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.outline,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              AppText(
                title,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          for (final book in books)
            Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Flexible(
                    child: AppText(
                      book,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(
                    Icons.menu_book_outlined,
                    size: 16.w,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
