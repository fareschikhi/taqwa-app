import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';

/// Confirmation dialog for switching a user account between active and
/// inactive, shared by the admin management cards.
///
/// Deactivating locks someone out of the app, so it is presented in the same
/// warning colours as a delete; activating is the reverse and reads as a
/// normal action. Either way the message names the person, because the button
/// that opens this sits on a card in a long list.
class ConfirmStatusDialog extends StatelessWidget {
  const ConfirmStatusDialog({
    super.key,
    required this.isCurrentlyActive,
    required this.userName,
  });

  /// The account's state *before* the change. `true` means the confirmed
  /// action is a deactivation.
  final bool isCurrentlyActive;

  final String userName;

  /// Shows the dialog and returns `true` only if the user confirmed.
  /// A tap outside dismisses with `null`, which counts as declining.
  static Future<bool> show(
    BuildContext context, {
    required bool isCurrentlyActive,
    required String userName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ConfirmStatusDialog(
        isCurrentlyActive: isCurrentlyActive,
        userName: userName,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final accent = isCurrentlyActive ? AppColors.error : AppColors.primary;
    final onAccent = isCurrentlyActive
        ? AppColors.onError
        : AppColors.onPrimary;
    final title = isCurrentlyActive ? 'تعطيل الحساب؟' : 'تفعيل الحساب؟';
    final confirmLabel = isCurrentlyActive ? 'تعطيل' : 'تفعيل';
    final message = isCurrentlyActive
        ? 'لن يتمكن $userName من تسجيل الدخول حتى إعادة تفعيل الحساب.'
        : 'سيتمكن $userName من تسجيل الدخول واستخدام التطبيق مجدداً.';

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
                    color: accent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCurrentlyActive
                        ? Icons.block
                        : Icons.check_circle_outline,
                    color: accent,
                    size: 22.w,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
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
            Text(
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
                    child: Text(
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
                      backgroundColor: accent,
                      foregroundColor: onAccent,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                      ),
                    ),
                    child: Text(
                      confirmLabel,
                      style: AppTextStyles.button.copyWith(color: onAccent),
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
