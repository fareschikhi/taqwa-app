import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import 'package:taqwa/core/models/halaqa_model.dart';
import 'package:taqwa/core/services/cloudinary_service.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';
import 'package:taqwa/features/data/repositories/student_repository.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';

class CreateStudentPage extends StatefulWidget {
  const CreateStudentPage({super.key});

  @override
  State<CreateStudentPage> createState() => _CreateStudentPageState();
}

class _CreateStudentPageState extends State<CreateStudentPage> {
  final _repo = StudentRepository();
  final _formKey = GlobalKey<FormState>();
  final _halaqaRepository = HalaqaRepository();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
  final _parentSearchController = TextEditingController();

  List<HalaqaModel> _halaqas = [];
  bool _isLoading = false;
  int? _selectedHalaqaId;
  int? _selectedParentId;
  XFile? _selectedImage;
  DateTime? _selectedBirthDate;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadHalaqas();
  }

  Future<void> _loadHalaqas() async {
    final result = await _halaqaRepository.getAllHalaqas();
    if (mounted) setState(() => _halaqas = result);
  }

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
        avatarUrl = await CloudinaryService.uploadImage(_selectedImage!);
      }

      final birthDateIso =
          '${_selectedBirthDate!.year}-${_selectedBirthDate!.month.toString().padLeft(2, '0')}-${_selectedBirthDate!.day.toString().padLeft(2, '0')}';

      await _repo.createStudent(
        StudentPayloadDto(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          birthDate: birthDateIso,
          address: _addressController.text.trim(),
          halaqaId: _selectedHalaqaId,
          parentId: _selectedParentId,
          avatar: avatarUrl,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة الطالب بنجاح')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StudentRepository.errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _parentSearchController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
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
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusXl,
                          ),
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
                                          : 'انقر لاختيار صورة (Cloudinary)',
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
                            // Name
                            _FieldLabel(label: 'اسم و لقب الطالب *'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'أدخل اسم الطالب كاملاً',
                              controller: _nameController,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: AppColors.onSurfaceVariant,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                            SizedBox(height: 16.h),
                            // Phone
                            _FieldLabel(label: 'رقم الهاتف *'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'أدخل رقم الهاتف',
                              controller: _phoneController,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: AppColors.onSurfaceVariant,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                            SizedBox(height: 16.h),
                            // Birth date
                            _FieldLabel(label: 'تاريخ الميلاد'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'dd/mm/yyyy',
                              controller: _dobController,
                              readOnly: true,
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime(2012),
                                  firstDate: DateTime(1990),
                                  lastDate: DateTime.now(),
                                  locale: const Locale('ar'),
                                );
                                if (picked != null) {
                                  _selectedBirthDate = picked;
                                  _dobController.text =
                                      '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                                }
                              },
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                                color: AppColors.onSurfaceVariant,
                              ),
                              suffixIcon: const Icon(
                                Icons.calendar_month,
                                color: AppColors.onSurfaceVariant,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                            SizedBox(height: 16.h),

                            // Adress
                            _FieldLabel(label: 'العنوان'),
                            SizedBox(height: 6.h),
                            AppTextField(
                              hint: 'أدخل العنوان',
                              controller: _addressController,
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                color: AppColors.onSurfaceVariant,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'هذا الحقل مطلوب'
                                  : null,
                            ),
                            SizedBox(height: 16.h),
                            // halaqa Selection (Optional)
                            _FieldLabel(label: 'المعلم المسؤول (اختياري)'),
                            SizedBox(height: 6.h),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                ),
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedHalaqaId,
                                  isExpanded: true,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primary,
                                  ),
                                  hint: Text(
                                    'اختر المعلم (اختياري)',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.inputPlaceholder,
                                    ),
                                  ),
                                  items: _halaqas
                                      .map(
                                        (halaqa) => DropdownMenuItem<int>(
                                          value: halaqa.id,
                                          child: Text(
                                            halaqa.name,
                                            style: AppTextStyles.bodyMd,
                                            textAlign: TextAlign.end,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedHalaqaId = v),
                                ),
                              ),
                            ),
                            SizedBox(height: 16.h),
                            // Halaqa (info)
                            _FieldLabel(label: 'الحلقة القرآنية'),
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 14.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusMd,
                                ),
                                border: Border.all(
                                  color: AppColors.inputBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 16,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  const Spacer(),
                                  Text(
                                    'يتم التعيين تلقائياً بناءً على المعلم',
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 24.h),
                      AppButton(
                        label: 'حفظ بيانات الطالب',
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
          Icon(Icons.person_add_outlined, color: AppColors.primary, size: 22.w),
          SizedBox(width: 8.w),
          Text(
            'إضافة طالب جديد',
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
    style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
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
