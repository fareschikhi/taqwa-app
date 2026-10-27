import 'package:flutter/material.dart';
import 'package:taqwa/features/shared/presentation/widgets/contact_owners_hint.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/account_validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../data/models/parent/parent_child_model.dart';
import '../../../data/models/parent/parent_model.dart';
import '../../../data/models/parent/parent_payload_dto.dart';
import '../../../data/repositories/parent_repository.dart';
import '../widgets/avatar_picker_field.dart';
import '../widgets/form_section.dart';
import '../widgets/linked_student_tile.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Create or edit a parent account. Shared by the admin and the manager
/// sections — both roles hit the same POST/PATCH /parents routes, so they get
/// the same form, photo picker included.
class ParentFormPage extends StatefulWidget {
  const ParentFormPage({super.key, this.parent});

  /// Parent being edited; null means "create a new one".
  final ParentModel? parent;

  @override
  State<ParentFormPage> createState() => _ParentFormPageState();
}

class _ParentFormPageState extends State<ParentFormPage> {
  final _repo = ParentRepository();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _addressController = TextEditingController();

  XFile? _pickedImage;
  bool _isLoading = false;

  bool get _isEditing => widget.parent != null;

  @override
  void initState() {
    super.initState();
    final parent = widget.parent;
    if (parent != null) {
      _nameController.text = parent.fullName;
      _phoneController.text = parent.phone ?? '';
      _emailController.text = parent.email ?? '';
      _addressController.text = parent.address ?? '';
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ImageUploadService.uploadImage(_pickedImage!);
      }

      final password = _passwordController.text.trim();

      if (_isEditing) {
        await _repo.updateParent(widget.parent!.id!, {
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'address': _addressController.text.trim(),
          'avatar': ?avatarUrl,
          if (password.isNotEmpty) 'password': password,
        });
      } else {
        await _repo.createParent(
          ParentPayloadDto(
            fullName: _nameController.text.trim(),
            password: password,
            phone: _phoneController.text.trim(),
            email: _emailController.text.trim(),
            address: _addressController.text.trim(),
            avatar: avatarUrl,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isEditing
                ? 'تم تحديث بيانات ولي الأمر'
                : 'تم إضافة ولي الأمر بنجاح',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(ParentRepository.errorMessage(e))));
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
            _buildHeader(),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(height: 24.h),
                      _buildCard(),
                      if (_isEditing) ...[
                        SizedBox(height: 16.h),
                        _buildStudentsCard(widget.parent!.children),
                      ],
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

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(18, 52, 59, 0.04),
            blurRadius: 20,
            offset: Offset(0, 4),
          ),
        ],
      );

  /// The parent's linked students, as they came with the parent from
  /// GET /parents. Tapping one opens its details page.
  Widget _buildStudentsCard(List<ParentChildModel> students) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FormSectionHeader(
            icon: Icons.school_outlined,
            title: 'الطلاب المرتبطون (${students.length})',
          ),
          SizedBox(height: 12.h),
          if (students.isEmpty)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppText(
                'لا يوجد طلاب مرتبطون بولي الأمر هذا.',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final student in students) ...[
              LinkedStudentTile(student: student),
              if (student != students.last) SizedBox(height: 8.h),
            ],
        ],
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AvatarPickerField(
            picked: _pickedImage,
            existingUrl: widget.parent?.avatar,
            onPicked: (img) => setState(() => _pickedImage = img),
          ),
          SizedBox(height: 20.h),
          const FormSectionHeader(
            icon: Icons.person_outline,
            title: 'البيانات الشخصية',
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'اسم ولي الأمر كاملاً *',
            hint: 'أدخل الاسم الكامل',
            controller: _nameController,
            prefixIcon: const Icon(
              Icons.badge_outlined,
              color: AppColors.onSurfaceVariant,
            ),
            validator: AccountValidators.fullName,
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
          SizedBox(height: 24.h),
          const FormSectionHeader(
            icon: Icons.contact_phone_outlined,
            title: 'بيانات الاتصال والحساب',
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'رقم الهاتف',
            hint: '05XXXXXXXX',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            maxLength: AccountValidators.phoneLength,
            inputFormatters: AccountValidators.phoneInputFormatters,
            validator: AccountValidators.phone,
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          ContactOwnersHint(
            controller: _phoneController,
            field: ContactField.phone,
            excludeUserId: widget.parent?.userId,
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'البريد الإلكتروني (اختياري)',
            hint: 'example@email.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: AccountValidators.email,
            prefixIcon: const Icon(
              Icons.email_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          ContactOwnersHint(
            controller: _emailController,
            field: ContactField.email,
            excludeUserId: widget.parent?.userId,
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: _isEditing
                ? 'كلمة المرور الجديدة (اتركها فارغة للإبقاء)'
                : 'كلمة المرور الافتراضية *',
            hint: '••••••••',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: const Icon(
              Icons.lock_outline,
              color: AppColors.onSurfaceVariant,
            ),
            // Editing keeps the current password when left blank, so only a
            // typed value is length-checked there.
            validator: (v) =>
                AccountValidators.password(v, optional: _isEditing),
          ),
          SizedBox(height: 4.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppText(
              'سيتمكن ولي الأمر من تغييرها لاحقاً.',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_forward_ios),
          ),
          const Spacer(),
          Icon(
            _isEditing ? Icons.edit_outlined : Icons.family_restroom,
            color: AppColors.primary,
            size: 22.w,
          ),
          SizedBox(width: 8.w),
          AppText(
            _isEditing ? 'تعديل ولي أمر' : 'إضافة ولي أمر جديد',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
