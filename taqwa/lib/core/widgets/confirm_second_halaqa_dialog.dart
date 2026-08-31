import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Confirmation for handing a teacher a halaqa on top of one she already runs.
///
/// The school's norm is one halaqa per teacher, so this is not a refusal —
/// the admin is allowed to stack them — but it is a departure worth meaning.
/// The message names the halaqas she already runs rather than counting them,
/// because a count would send the admin off to look them up before she could
/// tell a deliberate second assignment from a misclick in the picker.
class ConfirmSecondHalaqaDialog extends StatelessWidget {
  const ConfirmSecondHalaqaDialog({
    super.key,
    required this.teacherName,
    required this.existingHalaqas,
  });

  final String teacherName;

  /// The halaqas she already runs, excluding the one being saved. Never empty:
  /// the caller only opens this dialog when there is something to name.
  final List<String> existingHalaqas;

  /// Shows the dialog and returns `true` only if the admin confirmed.
  /// A tap outside dismisses with `null`, which counts as declining.
  static Future<bool> show(
    BuildContext context, {
    required String teacherName,
    required List<String> existingHalaqas,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmSecondHalaqaDialog(
        teacherName: teacherName,
        existingHalaqas: existingHalaqas,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final message =
        '$teacherName مسؤول بالفعل عن: ${existingHalaqas.join('، ')}.\n'
        'الأصل أن يتولى كل معلم حلقة واحدة، فتأكد قبل المتابعة.';

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
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
                    color: AppColors.warning.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 22.w,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: AppText(
                    'إسناد حلقة ثانية؟',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // A teacher can already run several halaqas, and the message names
            // every one of them, so the body has to yield rather than push the
            // buttons off a short screen.
            Flexible(
              child: SingleChildScrollView(
                child: AppText(
                  message,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
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
                      backgroundColor: AppColors.warning,
                      foregroundColor: AppColors.onSurface,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: AppText(
                      'إسناد',
                      style: AppTextStyles.button.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
