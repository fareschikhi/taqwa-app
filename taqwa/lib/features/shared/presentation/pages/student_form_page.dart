import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_selector_field.dart';
import '../../../data/models/student/student_model.dart';
import '../../../data/models/student/student_payload_dto.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../widgets/avatar_picker_field.dart';
import '../widgets/form_section.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Create or edit a student. Shared by the admin and the manager sections —
/// both roles hit the same POST/PATCH /students routes, so they get the same
/// form, photo picker included.
///
/// The one role-dependent bit is where the halaqa list comes from: pass
/// [managerId] for a manager and the options are scoped to that manager's
/// halaqas, because GET /halaqas is ADMIN/TEACHER-only.
class StudentFormPage extends StatefulWidget {
  const StudentFormPage({super.key, this.student, this.managerId});

  /// Student being edited; null means "create a new one".
  final StudentModel? student;

  /// Set when a manager is using the form.
  final int? managerId;

  @override
  State<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends State<StudentFormPage> {
  final _repo = StudentRepository();
  final _halaqaRepo = HalaqaRepository();
  final _parentRepo = ParentRepository();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();

  List<HalaqaModel> _halaqas = [];
  List<UserOption> _parents = [];
  int? _selectedHalaqaId;
  int? _selectedParentId;
  DateTime? _selectedBirthDate;
  XFile? _pickedImage;
  bool _isLoading = false;

  bool get _isEditing => widget.student != null;

  @override
  void initState() {
    super.initState();
    final student = widget.student;
    if (student != null) {
      _nameController.text = student.fullName;
      _phoneController.text = student.phone ?? '';
      _addressController.text = student.address;
      _selectedHalaqaId = student.halaqaId;
      _selectedParentId = student.parentId;

      final birthDate = DateTime.tryParse(student.birthDate);
      if (birthDate != null) {
        _selectedBirthDate = birthDate;
        _dobController.text = _formatDate(birthDate);
      }
    }
    _loadOptions();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Halaqas and parents are conveniences, not requirements: a role that
  /// can't read either list still gets a working form, just without that
  /// picker, so one 403 never blocks the whole page.
  Future<void> _loadOptions() async {
    final managerId = widget.managerId;

    List<HalaqaModel> halaqas = [];
    try {
      halaqas = managerId != null
          ? await _halaqaRepo.getManagerHalaqas(managerId)
          : await _halaqaRepo.getAllHalaqas();
    } catch (_) {}

    List<UserOption> parents = [];
    try {
      parents = (await _parentRepo.getAllParents())
          .where((p) => p.id != null)
          .map(
            (p) => UserOption(
              id: p.id!,
              fullName: p.fullName,
              avatar: p.avatar,
            ),
          )
          .toList();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _halaqas = halaqas;
        _parents = parents;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      String? avatarUrl;
      if (_pickedImage != null) {
        avatarUrl = await ImageUploadService.uploadImage(_pickedImage!);
      }

      final birthDate = _selectedBirthDate;

      if (_isEditing) {
        await _repo.updateStudent(widget.student!.id!, {
          'fullName': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
          'address': _addressController.text.trim(),
          if (birthDate != null) 'birthDate': _isoDate(birthDate),
          'halaqaId': ?_selectedHalaqaId,
          'parentId': ?_selectedParentId,
          'avatar': ?avatarUrl,
        });
      } else {
        await _repo.createStudent(
          StudentPayloadDto(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            birthDate: _isoDate(birthDate!),
            address: _addressController.text.trim(),
            halaqaId: _selectedHalaqaId,
            parentId: _selectedParentId,
            avatar: avatarUrl,
          ),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isEditing ? 'تم تحديث بيانات الطالب' : 'تم إضافة الطالب بنجاح',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(StudentRepository.errorMessage(e))));
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
                      SizedBox(height: 24.h),
                      AppButton(
                        label: _isEditing
                            ? 'حفظ التعديلات'
                            : 'حفظ بيانات الطالب',
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

  Widget _buildCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
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
          AvatarPickerField(
            picked: _pickedImage,
            existingUrl: widget.student?.avatar,
            onPicked: (img) => setState(() => _pickedImage = img),
          ),
          SizedBox(height: 20.h),
          const FormSectionHeader(
            icon: Icons.person_outline,
            title: 'البيانات الشخصية',
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'اسم و لقب الطالب *',
            hint: 'أدخل اسم الطالب كاملاً',
            controller: _nameController,
            prefixIcon: const Icon(
              Icons.person_outline,
              color: AppColors.onSurfaceVariant,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'تاريخ الميلاد *',
            hint: 'dd/mm/yyyy',
            controller: _dobController,
            readOnly: true,
            onTap: _pickBirthDate,
            prefixIcon: const Icon(
              Icons.calendar_today_outlined,
              color: AppColors.onSurfaceVariant,
            ),
            suffixIcon: const Icon(
              Icons.calendar_month,
              color: AppColors.onSurfaceVariant,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'العنوان *',
            hint: 'أدخل العنوان',
            controller: _addressController,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.onSurfaceVariant,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 24.h),
          const FormSectionHeader(
            icon: Icons.contact_phone_outlined,
            title: 'بيانات الاتصال',
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'رقم الهاتف *',
            hint: '05 123 456 789',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: AppColors.onSurfaceVariant,
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 24.h),
          const FormSectionHeader(
            icon: Icons.school_outlined,
            title: 'الحلقة وولي الأمر',
          ),
          SizedBox(height: 16.h),
          const FormFieldLabel(label: 'الحلقة القرآنية (اختياري)'),
          SizedBox(height: 6.h),
          _buildHalaqaDropdown(),
          SizedBox(height: 16.h),
          if (_parents.isNotEmpty)
            UserSelectorField(
              label: 'ولي الأمر (اختياري)',
              hint: 'ابحث واختر ولي الأمر',
              searchHint: 'ابحث باسم ولي الأمر',
              emptyText: 'لا يوجد أولياء أمور',
              options: _parents,
              selectedId: _selectedParentId,
              onSelected: (o) => setState(() => _selectedParentId = o.id),
            ),
        ],
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2012),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('ar'),
    );
    if (picked == null) return;
    setState(() {
      _selectedBirthDate = picked;
      _dobController.text = _formatDate(picked);
    });
  }

  Widget _buildHalaqaDropdown() {
    // A halaqa the caller can't see (an admin-assigned one, for a manager)
    // would make the dropdown throw on a value with no matching item.
    final hasSelected = _halaqas.any((h) => h.id == _selectedHalaqaId);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: hasSelected ? _selectedHalaqaId : null,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
          hint: AppText(
            _halaqas.isEmpty ? 'لا توجد حلقات متاحة' : 'اختر الحلقة (اختياري)',
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.inputPlaceholder,
            ),
            textAlign: TextAlign.end,
          ),
          items: _halaqas
              .map(
                (h) => DropdownMenuItem<int>(
                  value: h.id,
                  child: AppText(
                    h.name,
                    style: AppTextStyles.bodyMd,
                    textAlign: TextAlign.end,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => _selectedHalaqaId = v),
        ),
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
            _isEditing ? Icons.edit_outlined : Icons.person_add_outlined,
            color: AppColors.primary,
            size: 22.w,
          ),
          SizedBox(width: 8.w),
          AppText(
            _isEditing ? 'تعديل بيانات الطالب' : 'إضافة طالب جديد',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
