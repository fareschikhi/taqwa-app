import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import 'package:taqwa/features/shared/presentation/widgets/contact_owners_hint.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/utils/account_validators.dart';
import '../../../../core/providers/auth_provider.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import '../widgets/change_password_sheet.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import 'package:taqwa/features/data/repositories/auth_repository_impl.dart';

/// Every role that can open the profile needs its own name. A manager used to
/// fall through to the parent default and be shown as "ولي أمر".
String roleLabelFor(UserRole role) {
  switch (role) {
    case UserRole.admin:
      return 'مدير النظام';
    case UserRole.manager:
      return 'مشرف';
    case UserRole.teacher:
      return 'معلم';
    case UserRole.parent:
      return 'ولي أمر';
    case UserRole.student:
      return 'طالب';
    case UserRole.adultStudent:
      return 'طالب بالغ';
  }
}

/// Changing an account is an administrator's job — details and password
/// alike. Everyone else sees their own record but cannot alter any of it; an
/// admin edits them through the management pages, which already carry a form
/// with those fields for every role.
///
/// This is what the login screen's forgot-password dialog already promises:
/// contact the school administration.
bool canEditProfile(UserRole role) => role == UserRole.admin;

/// The avatar letter. Taken from the name rather than the role, so two
/// teachers no longer show the same initial.
String initialFor(String fullName) {
  final trimmed = fullName.trim();
  return trimmed.isEmpty ? '؟' : trimmed.characters.first;
}

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key, required this.role});

  /// Kept for the callers that already pass it; the details on screen come
  /// from the signed-in user rather than this string.
  final String role;

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _editMode = false;
  bool _isSaving = false;
  final ImagePicker _picker = ImagePicker();

  /// A photo picked in edit mode. It is only uploaded on save, and its bytes
  /// drive the preview, which works on the web build where dart:io does not.
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  void _toggleEditMode() => setState(() {
    _editMode = !_editMode;
    // Cancelling drops a photo that was picked but never saved.
    if (!_editMode) {
      _selectedImage = null;
      _selectedImageBytes = null;
    }
  });

  Future<void> _pickFrom(ImageSource source) async {
    final img = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: AppConstants.pickedImageMaxDimension,
      maxHeight: AppConstants.pickedImageMaxDimension,
    );
    if (img == null) return;
    final bytes = await img.readAsBytes();
    if (!mounted) return;
    setState(() {
      _selectedImage = img;
      _selectedImageBytes = bytes;
    });
  }

  void _pickImage() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: AppText('اختيار من المعرض', style: AppTextStyles.bodyMd),
              onTap: () {
                Navigator.pop(ctx);
                _pickFrom(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title: AppText(
                'التقاط صورة بالكاميرا',
                style: AppTextStyles.bodyMd,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickFrom(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Set once the controllers have been seeded, so a rebuild while the user is
  /// typing does not overwrite what they have entered.
  bool _seeded = false;

  void _seedFrom(UserModel user) {
    if (_seeded) return;
    _nameController.text = user.fullName;
    _phoneController.text = user.phone ?? '';
    _emailController.text = user.email ?? '';
    _seeded = true;
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await ImageUploadService.uploadImage(_selectedImage!);
      }
      await ref
          .read(authProvider.notifier)
          .updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            avatar: avatarUrl,
          );
      if (!mounted) return;
      setState(() {
        _editMode = false;
        _selectedImage = null;
        _selectedImageBytes = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم حفظ التغييرات')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(AuthRepository.errorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
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
    // AuthGate is the root and shows the login form itself once the session
    // is gone. This only clears anything pushed on top of it.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    _seedFrom(user);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.read(authProvider.notifier).checkAutoLogin(),
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
                        if (canEditProfile(user.role))
                        GestureDetector(
                          onTap: _toggleEditMode,
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
                                AppText(
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
                        AppText(
                          'الحساب',
                          style: AppTextStyles.headlineMd.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20.h),
                    // Avatar
                    GestureDetector(
                      onTap: _editMode ? _pickImage : null,
                      child: Stack(
                      children: [
                        // The ring is drawn around the photo, so the image
                        // itself is the circle inside the 3px border.
                        Container(
                          width: 90.w,
                          height: 90.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.onPrimary.withValues(alpha: 0.5),
                              width: 3,
                            ),
                          ),
                          child: _selectedImageBytes != null
                              ? ClipOval(
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : AvatarWidget(
                                  avatarUrl: user.avatar,
                                  size: 90.w - 6,
                                  backgroundColor: AppColors.onPrimary
                                      .withValues(alpha: 0.2),
                                  fallback: AppText(
                                    initialFor(user.fullName),
                                    style: AppTextStyles.headlineLgMobile
                                        .copyWith(color: AppColors.onPrimary),
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
                    ),
                    SizedBox(height: 12.h),
                    AppText(
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
                      child: AppText(
                        roleLabelFor(user.role),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
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
                      hint: '05XXXXXXXX',
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      maxLength: AccountValidators.phoneLength,
                      inputFormatters: AccountValidators.phoneInputFormatters,
                      enabled: _editMode,
                      prefixIcon: const Icon(
                        Icons.phone_outlined,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (_editMode) ContactOwnersHint(
                      controller: _phoneController,
                      field: ContactField.phone,
                      excludeUserId: user.id,
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
                    if (_editMode) ContactOwnersHint(
                      controller: _emailController,
                      field: ContactField.email,
                      excludeUserId: user.id,
                    ),
                    if (_editMode) ...[
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'حفظ التغييرات',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                    ],
                    SizedBox(height: 24.h),
                    if (canEditProfile(user.role)) ...[
                      _SettingsTile(
                        icon: Icons.lock_outline,
                        title: 'تغيير كلمة المرور',
                        onTap: () => ChangePasswordSheet.show(context),
                      ),
                      SizedBox(height: 24.h),
                    ],
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
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      AppText(
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
            AppText(
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
