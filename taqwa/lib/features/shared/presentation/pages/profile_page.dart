import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/auth/presentation/pages/login_page.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/providers/auth_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.role});
  final String role;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController(text: 'أحمد محمد السالم');
  final _phoneController = TextEditingController(text: '0501234567');
  final _emailController = TextEditingController(text: 'ahmed@farqan.edu.sa');
  bool _editMode = false;
  bool _isSaving = false;

  String get _roleLabel {
    switch (widget.role) {
      case 'admin':
        return 'مدير النظام';
      case 'teacher':
        return 'معلم';
      default:
        return 'ولي أمر';
    }
  }

  String get _roleIcon {
    switch (widget.role) {
      case 'admin':
        return 'م';
      case 'teacher':
        return 'أ';
      default:
        return 'خ';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _logout() async {
    await ref.read(authProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {},
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
            children: [
              // Header gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
                decoration: const BoxDecoration(
                  gradient: AppColors.brandGradient,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _editMode = !_editMode),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12.w,
                              vertical: 6.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.onPrimary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusFull,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _editMode ? Icons.close : Icons.edit_outlined,
                                  color: AppColors.onPrimary,
                                  size: 16.w,
                                ),
                                SizedBox(width: 4.w),
                                Text(
                                  _editMode ? 'إلغاء' : 'تعديل',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.onPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'الحساب',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    // Avatar
                    Stack(
                      children: [
                        Container(
                          width: 90.w,
                          height: 90.w,
                          decoration: BoxDecoration(
                            color: AppColors.onPrimary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.onPrimary.withValues(alpha: 0.5),
                              width: 3,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              _roleIcon,
                              style: AppTextStyles.headlineLgMobile.copyWith(
                                color: AppColors.onPrimary,
                              ),
                            ),
                          ),
                        ),
                        if (_editMode)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            child: Container(
                              width: 28.w,
                              height: 28.w,
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: AppColors.primary,
                                size: 16.w,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      _nameController.text,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.onPrimary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                      ),
                      child: Text(
                        _roleLabel,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24.h),
                    // Personal info section
                    _SectionHeader(
                      title: 'البيانات الشخصية',
                      icon: Icons.person_outline,
                    ),
                    SizedBox(height: 16.h),
                    AppTextField(
                      label: 'الاسم الكامل',
                      hint: 'أدخل اسمك الكامل',
                      controller: _nameController,
                      enabled: _editMode,
                    ),
                    SizedBox(height: 14.h),
                    AppTextField(
                      label: 'رقم الهاتف',
                      hint: '05X XXX XXXX',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: _editMode,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 14.h),
                    AppTextField(
                      label: 'البريد الإلكتروني',
                      hint: 'example@email.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: _editMode,
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (_editMode) ...[
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'حفظ التغييرات',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isSaving,
                        onPressed: () {
                          setState(() => _isSaving = true);
                          Future.delayed(const Duration(seconds: 1), () {
                            if (mounted) {
                              setState(() {
                                _isSaving = false;
                                _editMode = false;
                              });
                            }
                          });
                        },
                      ),
                    ],
                    SizedBox(height: 24.h),
                    _SettingsTile(
                      icon: Icons.lock_outline,
                      title: 'تغيير كلمة المرور',
                      onTap: () {},
                    ),
                    SizedBox(height: 24.h),
                    // Logout
                    AppButton(
                      label: 'تسجيل الخروج',
                      variant: AppButtonVariant.secondary,
                      icon: Icons.logout,
                      onPressed: () => _logout(),
                    ),
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.start,
    children: [
      Text(
        title,
        style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
      ),
      SizedBox(width: 8.w),
      Icon(icon, color: AppColors.primary, size: 20.w),
    ],
  );
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.icon, required this.title, this.onTap});
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          children: [
            const Icon(Icons.chevron_left, color: AppColors.onSurfaceVariant),
            const Spacer(),
            Text(
              title,
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            ),
            SizedBox(width: 12.w),
            Icon(icon, color: AppColors.primary, size: 22.w),
          ],
        ),
      ),
    );
  }
}
