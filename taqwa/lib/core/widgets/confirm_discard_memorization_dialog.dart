import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';

/// Warns the teacher that marking a student absent discards the memorization
/// already recorded for that student today.
///
/// A student who was not in the halaqa cannot have recited in it, so the two
/// records cannot both stand. Attendance wins, but the recitation is real work
/// that someone entered by hand, so it is never dropped silently.
class ConfirmDiscardMemorizationDialog extends StatelessWidget {
  const ConfirmDiscardMemorizationDialog({
    super.key,
    required this.studentName,
  });

  final String studentName;

  /// Shows the dialog and returns `true` only if the teacher confirmed.
  /// A tap outside dismisses with `null`, which counts as declining.
  static Future<bool> show(
    BuildContext context, {
    required String studentName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ConfirmDiscardMemorizationDialog(studentName: studentName),
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
      // A long student name pushes the message onto extra lines, so the
      // content scrolls rather than overflowing on a short screen.
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
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 22.w,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'حذف تسميع اليوم؟',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'تم تسجيل تسميع لـ $studentName اليوم. تحديده كغائب سيحذف هذا '
                'التسجيل نهائياً.',
                style: AppTextStyles.bodyMd.copyWith(
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
                      child: Text(
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
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onError,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        'تحديد كغائب',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onError,
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
