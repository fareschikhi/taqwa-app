import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_logo.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/shared/presentation/widgets/change_password_sheet.dart';

/// Shown by [AuthGate] in place of the home screen while the signed-in user is
/// on a password an admin set. It replaces the home rather than sitting over
/// it, so there is no back gesture or barrier tap that gets past it — the only
/// ways out are a new password or signing out.
class ForcePasswordChangePage extends ConsumerWidget {
  const ForcePasswordChangePage({super.key, this.onSubmit});

  /// Defaults to the repository. Injected in tests.
  final ChangePasswordAction? onSubmit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.read(authProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppLogo(height: 80.w),
                SizedBox(height: 24.h),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppConstants.radiusXl),
                  ),
                  padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 20.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(
                        'تعيين كلمة مرور جديدة',
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      AppText(
                        'كلمة المرور الحالية مؤقتة وضعتها الإدارة. '
                        'اختر كلمة مرور جديدة لمتابعة استخدام التطبيق.',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      ChangePasswordForm(
                        onSubmit: onSubmit,
                        // The gate re-routes to the role's home on its own
                        // once the flag clears.
                        onChanged: auth.passwordChanged,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 12.h),
                AppButton(
                  label: 'تسجيل الخروج',
                  variant: AppButtonVariant.tertiary,
                  onPressed: auth.logout,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
