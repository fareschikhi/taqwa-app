import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/models/teacher/teacher_payload_dto.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import '../../../data/repositories/teacher_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class CreateTeacherPage extends StatefulWidget {
  /// Pass [editTeacher] to pre-fill the form for editing an existing teacher.
  const CreateTeacherPage({super.key, this.editTeacher});
  final TeacherModel? editTeacher;

  @override
  State<CreateTeacherPage> createState() => _CreateTeacherPageState();
}

class _CreateTeacherPageState extends State<CreateTeacherPage> {
  final _repo = TeacherRepository();
  final _formKey = GlobalKey<FormState>();
  final _dobController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;
  XFile? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool get _isEditing => widget.editTeacher != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.editTeacher!;
      _nameController.text = t.fullName;
      _phoneController.text = t.phone ?? '';
      _emailController.text = t.email ?? '';
    }
  }

  /// The freshly picked file wins over the stored avatar, so the preview
  /// updates the moment the user chooses a new photo.
  DecorationImage? _avatarImage() {
    if (_selectedImage != null) {
      return DecorationImage(
        image: FileImage(File(_selectedImage!.path)),
        fit: BoxFit.cover,
      );
    }
    final existing = widget.editTeacher?.avatar;
    if (existing != null && existing.isNotEmpty) {
      return DecorationImage(image: NetworkImage(existing), fit: BoxFit.cover);
    }
    return null;
  }

  bool get _hasAvatarImage =>
      _selectedImage != null || (widget.editTeacher?.avatar?.isNotEmpty ?? false);

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
              leading: const Icon(
                Icons.photo_library,
                color: AppColors.primary,
              ),
              title: AppText('اختيار من المعرض', style: AppTextStyles.bodyMd),
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
              title: AppText('التقاط صورة بالكاميرا', style: AppTextStyles.bodyMd),
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
        avatarUrl = await ImageUploadService.uploadImage(_selectedImage!);
      }

      if (_isEditing) {
        final data = <String, dynamic>{
          'fullName': _nameController.text.trim(),
          if (_phoneController.text.trim().isNotEmpty)
            'phone': _phoneController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          if (_passwordController.text.isNotEmpty)
            'password': _passwordController.text,
          // No dateOfBirth/address here: UpdateTeacherDto declares neither and
          // the API's whitelisting ValidationPipe drops them without an error,
          // so the fields are hidden on edit rather than silently discarded.
        };
        if (avatarUrl != null) data['avatar'] = avatarUrl;
        await _repo.updateTeacher(widget.editTeacher!.id, data);
      } else {
        await _repo.createTeacher(
          TeacherPayloadDto(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            email: _emailController.text.trim().isEmpty
                ? null
                : _emailController.text.trim(),
            dateOfBirth: _dobController.text.isEmpty
                ? null
                : _dobController.text,
            address: _addressController.text.trim().isEmpty
                ? null
                : _addressController.text.trim(),
            avatar: avatarUrl,
          ),
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isEditing ? 'تم تحديث بيانات المعلم' : 'تم إضافة المعلم بنجاح',
          ),
        ),
      );

      Navigator.pop(context, true); // true = refresh caller list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(TeacherRepository.errorMessage(e))),
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
    _dobController.dispose(); // add this
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(height: 24.h),

                      // Photo Upload
                      Center(
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickImage,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 100.w,
                                    height: 100.w,
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerHigh,
                                      shape: BoxShape.circle,
                                      image: _avatarImage(),
                                    ),
                                    child: _hasAvatarImage
                                        ? null
                                        : Icon(
                                            Icons.camera_alt_outlined,
                                            color: AppColors.onSurfaceVariant,
                                            size: 36.w,
                                          ),
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
                                        _hasAvatarImage
                                            ? Icons.check
                                            : Icons.upload,
                                        color: AppColors.onPrimary,
                                        size: 16.w,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            AppText(
                              'الصورة الشخصية',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            AppText(
                              _selectedImage != null
                                  ? 'تم اختيار صورة'
                                  : 'PNG أو JPG (الحد الأقصى 2MB)',
                              style: AppTextStyles.labelSm.copyWith(
                                color: _selectedImage != null
                                    ? AppColors.primary
                                    : AppColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      // Section: Personal Data
                      _SectionHeader(
                        icon: Icons.person_outline,
                        title: 'البيانات الشخصية',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'اسم و لقب المعلم',
                        hint: 'أدخل الاسم كاملاً',
                        controller: _nameController,
                      ),
                      // Date of birth and address are create-only: the update
                      // endpoint stores neither, so showing them on edit would
                      // invite input that is dropped on save.
                      if (!_isEditing) ...[
                        SizedBox(height: 16.h),
                        AppTextField(
                          label: 'تاريخ الميلاد',
                          hint: 'dd/mm/yyyy',
                          controller: _dobController,
                          readOnly: true,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime(1990),
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              locale: const Locale('fr'),
                            );
                            if (picked != null) {
                              _dobController.text =
                                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            }
                          },
                          suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        AppTextField(
                          label: 'العنوان السكني',
                          hint: 'المدينة، الحي، الشارع',
                          controller: _addressController,
                        ),
                      ],
                      SizedBox(height: 24.h),
                      // Section: Contact & Employment
                      _SectionHeader(
                        icon: Icons.work_outline,
                        title: 'معلومات الاتصال والتوظيف',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'رقم الهاتف',
                        hint: '05X XXX XXXX',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'البريد الإلكتروني',
                        hint: 'example@domain.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: _isEditing
                            ? 'كلمة المرور الجديدة (اتركه فارغاً للإبقاء)'
                            : 'كلمة المرور المبدئية',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      SizedBox(height: 32.h),
                      // Buttons
                      AppButton(
                        label: _isEditing ? 'حفظ التعديلات' : 'حفظ المعلم',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isLoading,
                        onPressed: () => _submit(),
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

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_forward_ios),
                color: AppColors.onSurface,
              ),
              const Spacer(),
              AppText(
                'تقوى',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppText(
                _isEditing ? 'تعديل معلم' : 'إضافة معلم جديد',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              AppText(
                'إدارة المعلمين',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          AppText(
            _isEditing ? 'تعديل بيانات المعلم' : 'إضافة معلم جديد',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          AppText(
            _isEditing
                ? 'قم بتحديث بيانات المعلم.'
                : 'قم بإدخال بيانات المعلم الجديد لإضافته إلى النظام.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
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
        AppText(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
        ),
        SizedBox(width: 8.w),
        Icon(icon, color: AppColors.primary, size: 22.w),
      ],
    );
  }
}
