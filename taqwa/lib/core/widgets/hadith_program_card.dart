import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
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
    this.title = 'الحديث الشريف',
    this.onTap,
  });

  final List<String> books;
  final num? hadithsDone;
  final String title;
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
            children: [
              AppText(
                '${formatAmount(hadithsDone)} $kHadithUnitLabel محفوظ',
                style: AppTextStyles.labelMd.copyWith(color: AppColors.outline),
              ),
              const Spacer(),
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
