import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/models/teacher/teacher_payload_dto.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import '../../../data/repositories/teacher_repository.dart';

class CreateTeacherPage extends StatefulWidget {
  const CreateTeacherPage({super.key});

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

  // final _specializations = ['التجويد', 'الحفظ', 'القراءات', 'التفسير', 'الفقه'];

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
              title: Text('التقاط صورة بالكاميرا', style: AppTextStyles.bodyMd),
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

      await _repo.createTeacher(
        TeacherPayloadDto(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          dateOfBirth: _dobController.text.isEmpty ? null : _dobController.text,
          address: _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
          avatar: avatarUrl,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة المعلم بنجاح')));

      // if (addAnother) {
      //   _formKey.currentState!.reset();
      //   _nameController.clear();
      //   _phoneController.clear();
      //   _emailController.clear();
      //   _passwordController.clear();
      //   _addressController.clear();
      //   _dobController.clear();
      // } else {
      Navigator.pop(context, true); // true = refresh caller list
      // }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(TeacherRepository.errorMessage(e))),
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
                                            Icons.camera_alt_outlined,
                                            color: AppColors.onSurfaceVariant,
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
                                            ? Icons.upload
                                            : Icons.check,
                                        color: AppColors.onPrimary,
                                        size: 16.w,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              'الصورة الشخصية',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                            Text(
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
                        label: 'كلمة المرور المبدئية',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      // Text('التخصص', style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
                      // SizedBox(height: 6.h),
                      // Container(
                      //   decoration: BoxDecoration(
                      //     color: AppColors.surfaceContainerLowest,
                      //     borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                      //     border: Border.all(color: AppColors.inputBorder),
                      //   ),
                      //   padding: EdgeInsets.symmetric(horizontal: 16.w),
                      //   child: DropdownButtonHideUnderline(
                      //     child: DropdownButton<String>(
                      //       value: _specialization,
                      //       isExpanded: true,
                      //       hint: Text('اختر التخصص...',
                      //           style: AppTextStyles.labelMd.copyWith(color: AppColors.inputPlaceholder)),
                      //       items: _specializations.map((s) => DropdownMenuItem(
                      //         value: s, child: Text(s, style: AppTextStyles.bodyMd))).toList(),
                      //       onChanged: (v) => setState(() => _specialization = v),
                      //     ),
                      //   ),
                      // ),
                      // SizedBox(height: 16.h),
                      // AppTextField(label: 'تاريخ التعيين', hint: 'dd/mm/yyyy',
                      //     readOnly: true, onTap: () async {
                      //       await showDatePicker(
                      //         context: context,
                      //         initialDate: DateTime.now(),
                      //         firstDate: DateTime(2000),
                      //         lastDate: DateTime.now().add(const Duration(days: 365)),
                      //       );
                      //     },
                      //     suffixIcon: const Icon(Icons.calendar_today_outlined,
                      //         color: AppColors.onSurfaceVariant)),
                      SizedBox(height: 32.h),
                      // Buttons
                      AppButton(
                        label: 'حفظ المعلم',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isLoading,
                        onPressed: () => _submit(),
                      ),
                      SizedBox(height: 12.h),
                      // AppButton(
                      //   label: 'حفظ وإضافة آخر',
                      //   variant: AppButtonVariant.secondary,
                      //   icon: Icons.person_add,
                      //   onPressed: () => _submit(addAnother: true),
                      // ),
                      // SizedBox(height: 12.h),
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
              Text(
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
              Text(
                'إضافة معلم جديد',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 16,
                color: AppColors.onSurfaceVariant,
              ),
              Text(
                'إدارة المعلمين',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'إضافة معلم جديد',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            'قم بإدخال بيانات المعلم الجديد لإضافته إلى النظام.',
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
