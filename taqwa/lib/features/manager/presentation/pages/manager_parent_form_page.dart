import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../features/data/models/parent/parent_model.dart';
import '../../../../features/data/models/parent/parent_payload_dto.dart';
import '../../../../features/data/repositories/parent_repository.dart';

class ManagerParentFormPage extends StatefulWidget {
  const ManagerParentFormPage({super.key, this.editParent});

  final ParentModel? editParent;

  @override
  State<ManagerParentFormPage> createState() => _ManagerParentFormPageState();
}

class _ManagerParentFormPageState extends State<ManagerParentFormPage> {
  final _repo = ParentRepository();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool get _isEditing => widget.editParent != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final p = widget.editParent!;
      _nameController.text = p.fullName;
      _phoneController.text = p.phone ?? '';
      _emailController.text = p.email ?? '';
      _addressController.text = p.address ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      if (_isEditing) {
        final data = <String, dynamic>{
          'fullName': _nameController.text.trim(),
          if (_phoneController.text.trim().isNotEmpty)
            'phone': _phoneController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          if (_addressController.text.trim().isNotEmpty)
            'address': _addressController.text.trim(),
          if (_passwordController.text.isNotEmpty)
            'password': _passwordController.text,
        };
        await _repo.updateParent(widget.editParent!.id!, data);
      } else {
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
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'تم تحديث بيانات ولي الأمر'
                : 'تم إضافة ولي الأمر بنجاح',
          ),
        ),
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
                      AppTextField(
                        label: 'اسم ولي الأمر كاملاً',
                        hint: 'أدخل الاسم الكامل',
                        controller: _nameController,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'هذا الحقل مطلوب'
                            : null,
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
                        label: 'البريد الإلكتروني (اختياري)',
                        hint: 'example@email.com',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: 'العنوان / الحي (اختياري)',
                        hint: 'مثال: حي الياسمين، الرياض',
                        controller: _addressController,
                        prefixIcon: const Icon(
                          Icons.location_on_outlined,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      AppTextField(
                        label: _isEditing
                            ? 'كلمة المرور الجديدة (اتركها فارغة للإبقاء)'
                            : 'كلمة المرور الافتراضية',
                        hint: '••••••••',
                        controller: _passwordController,
                        obscureText: true,
                        validator: _isEditing
                            ? null
                            : (v) => (v == null || v.trim().length < 6)
                                ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                : null,
                        prefixIcon: const Icon(
                          Icons.lock_outline,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 32.h),
                      AppButton(
                        label: _isEditing
                            ? 'حفظ التعديلات'
                            : 'إنشاء حساب ولي الأمر',
                        variant: AppButtonVariant.gradient,
                        icon: Icons.save_outlined,
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

  Widget _buildAppBar(BuildContext context) {
    return Padding(
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
            _isEditing ? 'تعديل ولي أمر' : 'إضافة ولي أمر جديد',
            style: AppTextStyles.headlineLgMobile.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          Text(
            _isEditing
                ? 'قم بتحديث بيانات ولي الأمر.'
                : 'قم بإدخال بيانات ولي الأمر الجديد.',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
