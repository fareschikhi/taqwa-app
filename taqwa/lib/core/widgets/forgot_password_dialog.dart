import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Taqwa has no mailer and no SMS provider, and accounts are created by staff
/// rather than self-registered, so a forgotten password is reset by an
/// administrator. This dialog says so instead of leaving the link dead.
class ForgotPasswordDialog extends StatelessWidget {
  const ForgotPasswordDialog({super.key});

  static Future<void> show(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => const ForgotPasswordDialog(),
  );

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
            AppText(
              'نسيت كلمة المرور؟',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            SizedBox(height: 12.h),
            AppText(
              'يرجى التواصل مع إدارة المدرسة لإعادة تعيين كلمة المرور الخاصة بك.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 20.h),
            AppButton(
              label: 'حسناً',
              variant: AppButtonVariant.secondary,
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}
