import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Warns the teacher that this student already has recitation recorded today,
/// and that a new entry will be added alongside it.
///
/// Nothing is deleted here — the server appends every entry — so the warning is
/// about silent double-entry, not data loss. Recording حفظ and then مراجعة on
/// one day is ordinary work, which is why this confirms rather than blocks, and
/// why it is styled as a caution instead of a destructive action.
class ConfirmDuplicateMemorizationDialog extends StatelessWidget {
  const ConfirmDuplicateMemorizationDialog({
    super.key,
    required this.studentName,
    required this.existing,
  });

  final String studentName;

  /// One line per record already on file for today, newest last.
  final List<String> existing;

  /// Shows the dialog and returns `true` only if the teacher chose to carry on.
  /// A tap outside dismisses with `null`, which counts as declining.
  static Future<bool> show(
    BuildContext context, {
    required String studentName,
    required List<String> existing,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDuplicateMemorizationDialog(
        studentName: studentName,
        existing: existing,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      // A long name, or several entries already on file, push the content onto
      // extra lines, so it scrolls rather than overflowing on a short screen.
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.history_toggle_off,
                      color: AppColors.warning,
                      size: 22.w,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: AppText(
                      'تسجيل مكرر؟',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              AppText(
                'سُجّل لـ $studentName اليوم:',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final line in existing) ...[
                      AppText(
                        line,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      if (line != existing.last) SizedBox(height: 6.h),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 12.h),
              AppText(
                'سيُضاف تسجيل جديد إلى ما سبق ولن يُحذف أي منه.',
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: AppText(
                        'إلغاء',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: AppText(
                        'متابعة',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
