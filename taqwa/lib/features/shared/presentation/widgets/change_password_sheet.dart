import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/repositories/auth_repository_impl.dart';

/// Lets the signed-in user replace their own password. The current password is
/// required because the backend verifies it — this sheet cannot reset a
/// forgotten one, which is an administrator's job.
typedef ChangePasswordAction =
    Future<void> Function({
      required String currentPassword,
      required String newPassword,
    });

class ChangePasswordSheet extends StatefulWidget {
  const ChangePasswordSheet({super.key, this.onSubmit});

  /// Defaults to the repository. Injected in tests so a failure can be
  /// exercised without a server.
  final ChangePasswordAction? onSubmit;

  /// Returns true only when the password was actually changed.
  static Future<bool> show(BuildContext context) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
    return changed ?? false;
  }

  static String? validateCurrent(String? v) =>
      (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null;

  static String? validateNew(String? v) => (v == null || v.trim().length < 6)
      ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
      : null;

  static String? validateConfirm(String? v, String newPassword) =>
      v != newPassword ? 'كلمتا المرور غير متطابقتين' : null;

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _repo = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSaving = false;

  /// Rendered inside the sheet: a failure leaves the sheet open, and a
  /// SnackBar would be drawn underneath it where nobody can see it.
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });
    try {
      final submit = widget.onSubmit ?? _repo.changePassword;
      await submit(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      // The sheet closes first, so this SnackBar lands on the page behind it.
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم تغيير كلمة المرور بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = AuthRepository.errorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXl),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 24.h),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                'تغيير كلمة المرور',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 16.h),
              AppTextField(
                label: 'كلمة المرور الحالية',
                controller: _currentController,
                obscureText: true,
                validator: ChangePasswordSheet.validateCurrent,
              ),
              SizedBox(height: 12.h),
              AppTextField(
                label: 'كلمة المرور الجديدة',
                controller: _newController,
                obscureText: true,
                validator: ChangePasswordSheet.validateNew,
              ),
              SizedBox(height: 12.h),
              AppTextField(
                label: 'تأكيد كلمة المرور الجديدة',
                controller: _confirmController,
                obscureText: true,
                validator: (v) =>
                    ChangePasswordSheet.validateConfirm(v, _newController.text),
              ),
              if (_error != null) ...[
                SizedBox(height: 12.h),
                AppText(
                  _error!,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              SizedBox(height: 20.h),
              AppButton(
                label: 'حفظ',
                variant: AppButtonVariant.gradient,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
