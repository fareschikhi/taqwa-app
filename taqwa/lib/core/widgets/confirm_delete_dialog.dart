import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Reusable confirmation dialog for destructive delete actions.
class ConfirmDeleteDialog extends StatelessWidget {
  const ConfirmDeleteDialog({
    super.key,
    this.title = 'تأكيد الحذف',
    this.message = 'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.',
  });

  final String title;
  final String message;

  /// Shows the dialog and returns `true` only if the user tapped delete.
  static Future<bool> show(
    BuildContext context, {
    String title = 'تأكيد الحذف',
    String message = 'هل أنت متأكد من الحذف؟ لا يمكن التراجع عن هذا الإجراء.',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmDeleteDialog(title: title, message: message),
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
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 22.w,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: AppText(
                    title,
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
              message,
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
                    child: AppText(
                      'إغلاق',
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
                    child: AppText(
                      'حذف',
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
    );
  }
}
