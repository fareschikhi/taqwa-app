import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/models/student/student_payload_dto.dart';
import '../../../../features/data/repositories/student_repository.dart';

class ManagerAddStudentPage extends StatefulWidget {
  const ManagerAddStudentPage({super.key});

  @override
  State<ManagerAddStudentPage> createState() => _ManagerAddStudentPageState();
}

class _ManagerAddStudentPageState extends State<ManagerAddStudentPage> {
  final _repo = StudentRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submit({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _repo.createStudent(
        StudentPayloadDto(
          fullName: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          birthDate: _dobController.text.trim().isNotEmpty
              ? _dobController.text.trim()
              : DateTime.now().toIso8601String().split('T')[0],
          address: 'العنوان',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إضافة الطالب بنجاح')));
      if (addAnother) {
        _formKey.currentState!.reset();
        _nameController.clear();
        _phoneController.clear();
        _passwordController.clear();
        _dobController.clear();
      } else {
        Navigator.pop(context, true);
      }
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
    _phoneController.dispose();
    _passwordController.dispose();
    _dobController.dispose();
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
                      _SectionHeader(
                        icon: Icons.person_outline,
                        title: 'البيانات الشخصية',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'الاسم الكامل',
                        hint: 'أدخل الاسم كاملاً',
                        controller: _nameController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'هذا الحقل مطلوب'
                            : null,
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
                            initialDate: DateTime(2010),
                            firstDate: DateTime(1990),
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
                      SizedBox(height: 24.h),
                      _SectionHeader(
                        icon: Icons.contact_phone_outlined,
                        title: 'معلومات الاتصال',
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'رقم الهاتف *',
                        hint: '05 123 456 789',
                        controller: _phoneController,
                        keyboardType: TextInputType.number,
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'هذا الحقل مطلوب'
                            : null,
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
                      SizedBox(height: 32.h),
                      AppButton(
                        label: 'حفظ الطالب',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
                        isLoading: _isLoading,
                        onPressed: () => _submit(),
                      ),
                      SizedBox(height: 12.h),
                      AppButton(
                        label: 'حفظ وإضافة آخر',
                        variant: AppButtonVariant.secondary,
                        icon: Icons.person_add,
                        onPressed: () => _submit(addAnother: true),
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
              Text(
                'تقوى',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'إضافة طالب جديد',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            'قم بإدخال بيانات الطالب الجديد.',
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
