import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/core/services/cloudinary_service.dart';
import 'package:taqwa/features/data/models/parent/parent_payload_dto.dart';
import 'package:taqwa/features/data/repositories/parent_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class CreateParentPage extends StatefulWidget {
  const CreateParentPage({super.key});

  @override
  State<CreateParentPage> createState() => _CreateParentPageState();
}

class _CreateParentPageState extends State<CreateParentPage> {
  final _repo = ParentRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
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
              leading: const Icon(Icons.photo_library, color: AppColors.primary),
              title: Text('اختيار من المعرض', style: AppTextStyles.bodyMd),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (img != null && mounted) {
                  setState(() => _selectedImage = img);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppColors.primary),
              title:
                  Text('التقاط صورة بالكاميرا', style: AppTextStyles.bodyMd),
              onTap: () async {
                Navigator.pop(ctx);
                final img = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (img != null && mounted) {
                  setState(() => _selectedImage = img);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String? avatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await CloudinaryService.uploadImage(_selectedImage!);
      }

      await _repo.createParent(
        ParentPayloadDto(
          fullName: _nameController.text.trim(),
          password: _passwordController.text.trim(),
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          address: _addressController.text.trim().isNotEmpty
              ? _addressController.text.trim()
              : null,
          avatar: avatarUrl,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إضافة ولي الأمر بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ParentRepository.errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(height: 24.h),
                      // Card container
                      Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius:
                              BorderRadius.circular(AppConstants.radiusXl),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(18, 52, 59, 0.04),
                              blurRadius: 20,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            // Photo upload
                            Center(
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 100.w,
                                      height: 100.w,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceContainerHigh,
                                        shape: BoxShape.circle,
                                        image: _selectedImage != null
                                            ? DecorationImage(
                                                image: FileImage(
                                                  File(_selectedImage!.path),
                                                ),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: _selectedImage == null
                                          ? Icon(
                                              Icons.add_a_photo_outlined,
                                              color:
                                                  AppColors.onSurfaceVariant,
                                              size: 36.w,
                                            )
                                          : null,
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      child: Container(
                                        width: 32.w,
                                        height: 32.w,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.brandGradient,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _selectedImage == null
                                              ? Icons.edit
                                              : Icons.check,
                                          color: AppColors.onPrimary,
                                          size: 16.w,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 8.h),
                                child: Column(
                                  children: [
                                    Text(
                                      'الصورة الشخصية',
                                      style: AppTextStyles.labelMd.copyWith(
                                        color: AppColors.onSurface,
                                      ),
                                    ),
                                    Text(
                                      _selectedImage != null
                                          ? 'تم اختيار صورة'
                                          : 'انقر لاختيار صورة (اختياري)',
                                      style: AppTextStyles.labelSm.copyWith(
                                        color: _selectedImage != null
                                            ? AppColors.primary
                                            : AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 20.h),
                            _SectionHeader(
                              icon: Icons.person_outline,
                              title: 'البيانات الشخصية',
                            ),
                            SizedBox(height: 16.h),
                            // Full Name
                            _FieldLabel(label: 'اسم ولي الأمر كاملاً *'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'أدخل الاسم الكامل',
                              controller: _nameController,
                              prefixIcon: const Icon(
                                Icons.badge_outlined,
                                color: AppColors.onSurfaceVariant,
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'هذا الحقل مطلوب'
                                      : null,
                            ),
                            SizedBox(height: 24.h),
                            _SectionHeader(
                              icon: Icons.contact_phone_outlined,
                              title: 'بيانات الاتصال والحساب',
                            ),
                            SizedBox(height: 16.h),
                            // Phone
                            _FieldLabel(label: 'رقم الهاتف'),
                            SizedBox(height: 6.h),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd),
                                border:
                                    Border.all(color: AppColors.inputBorder),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.ltr,
                                      style: AppTextStyles.bodyMd,
                                      decoration: InputDecoration(
                                        hintText: '5X XXX XXXX',
                                        hintStyle:
                                            AppTextStyles.labelMd.copyWith(
                                          color: AppColors.inputPlaceholder,
                                        ),
                                        border: InputBorder.none,
                                        contentPadding:
                                            EdgeInsets.symmetric(
                                          horizontal: 16.w,
                                          vertical: 14.h,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                        horizontal: 12.w, vertical: 14.h),
                                    decoration: const BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                            color: AppColors.inputBorder),
                                      ),
                                    ),
                                    child: Text(
                                      '+966',
                                      style: AppTextStyles.labelMd.copyWith(
                                          color: AppColors.onSurface),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 16.h),
                            // Email
                            _FieldLabel(label: 'البريد الإلكتروني (اختياري)'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'example@email.com',
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              prefixIcon: const Icon(
                                Icons.email_outlined,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                            SizedBox(height: 16.h),
                            // Password
                            _FieldLabel(label: 'كلمة المرور الافتراضية *'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: '••••••••',
                              controller: _passwordController,
                              obscureText: true,
                              validator: (v) =>
                                  (v == null || v.trim().length < 6)
                                      ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                      : null,
                            ),
                            SizedBox(height: 4.h),
                            Align(
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                'سيتمكن ولي الأمر من تغييرها لاحقاً.',
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            // Address
                            _FieldLabel(label: 'العنوان / الحي (اختياري)'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'مثال: حي الياسمين، الرياض',
                              controller: _addressController,
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32.h),
                      AppButton(
                        label: 'إنشاء حساب ولي الأمر',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.person_add,
                        isLoading: _isLoading,
                        onPressed: _submit,
                      ),
                      SizedBox(height: 12.h),
                      AppButton(
                        label: 'إلغاء',
                        variant: AppButtonVariant.tertiary,
                        onPressed: () => Navigator.pop(context),
                      ),
                      SizedBox(height: 32.h),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
          const Spacer(),
          Icon(Icons.family_restroom, color: AppColors.primary, size: 22.w),
          SizedBox(width: 8.w),
          Text(
            'إضافة ولي أمر جديد',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style:
            AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
        ),
        SizedBox(width: 8.w),
        Icon(icon, color: AppColors.primary, size: 22.w),
      ],
    );
  }
}
