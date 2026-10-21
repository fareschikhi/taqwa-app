import 'package:flutter/material.dart';
import 'package:taqwa/features/shared/presentation/widgets/contact_owners_hint.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/hadith_books.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import 'package:taqwa/features/data/services/image_upload_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/account_validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_selector_field.dart';
import '../../../data/models/student/student_model.dart';
import '../../../data/models/student/student_payload_dto.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../widgets/avatar_picker_field.dart';
import '../widgets/change_password_sheet.dart';
import '../widgets/form_section.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Create or edit a student. Shared by the admin and the manager sections —
/// both roles hit the same POST/PATCH /students routes, so they get the same
/// form, photo picker included.
///
/// The one role-dependent bit is where the halaqa list comes from: pass
/// [managerId] for a manager and the options are scoped to that manager's
/// halaqas, because GET /halaqas is ADMIN/TEACHER-only.
///
/// The other is the hadith book checklist, shown and sent only when
/// [canSetHadithBooks] is true — the backend refuses the key from any role
/// but admin.
class StudentFormPage extends StatefulWidget {
  const StudentFormPage({
    super.key,
    this.student,
    this.managerId,
    this.canSetHadithBooks = false,
  });

  /// Student being edited; null means "create a new one".
  final StudentModel? student;

  /// Set when a manager is using the form.
  final int? managerId;

  /// Opt-in rather than derived from [managerId], so no caller other than
  /// the admin section ever offers a checklist the backend would reject.
  final bool canSetHadithBooks;

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
  final _passwordController = TextEditingController();

  // Registration-form (استمارة التسجيل) details. Which of them render — and
  // get sent — follows [_isAdultForm]; the rest keep their text so flipping
  // the switch back and forth loses nothing.
  final _schoolLevelController = TextEditingController();
  final _healthController = TextEditingController();
  final _familyStatusController = TextEditingController();
  final _fatherJobController = TextEditingController();
  final _motherJobController = TextEditingController();
  final _occupationController = TextEditingController();
  final _emailController = TextEditingController();
  final _activitiesController = TextEditingController();
  bool? _isMarried;

  List<HalaqaModel> _halaqas = [];
  List<UserOption> _parents = [];
  int? _selectedHalaqaId;
  int? _selectedParentId;
  DateTime? _selectedBirthDate;
  XFile? _pickedImage;
  bool _isLoading = false;

  /// An adult student is his own guardian — a real login, no parent — while
  /// a child is the reverse. Changing an existing person's role afterwards
  /// is out of scope (the backend has no path for it), so this only ever
  /// matters, and only ever renders, while creating.
  bool _isAdult = false;

  /// The hadith books the admin assigns this student, editable on both
  /// create and edit — unlike [_isAdult], nothing else on the form depends
  /// on it, so there is no reason to lock it after creation. None ticked
  /// means Quran only.
  final Set<String> _hadithBooks = {};

  bool get _isEditing => widget.student != null;

  /// Which registration form applies: the switch while creating, the
  /// student's own role while editing (the switch is hidden then).
  bool get _isAdultForm =>
      _isEditing ? widget.student!.isAdult : _isAdult;

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
      _hadithBooks.addAll(student.hadithBooks);
      _schoolLevelController.text = student.schoolLevel ?? '';
      _healthController.text = student.healthStatus ?? '';
      _familyStatusController.text = student.familyStatus ?? '';
      _fatherJobController.text = student.fatherJob ?? '';
      _motherJobController.text = student.motherJob ?? '';
      _occupationController.text = student.occupation ?? '';
      _emailController.text = student.email ?? '';
      _activitiesController.text = student.externalActivities ?? '';
      _isMarried = student.isMarried;

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
    _passwordController.dispose();
    _schoolLevelController.dispose();
    _healthController.dispose();
    _familyStatusController.dispose();
    _fatherJobController.dispose();
    _motherJobController.dispose();
    _occupationController.dispose();
    _emailController.dispose();
    _activitiesController.dispose();
    super.dispose();
  }

  /// The registration details for the form that applies, keyed as the
  /// backend names them. Blank text is sent as '' so an edit can clear a
  /// value; the backend stores it as null.
  Map<String, Object> _registration() {
    final common = {
      'schoolLevel': _schoolLevelController.text.trim(),
      'healthStatus': _healthController.text.trim(),
      'familyStatus': _familyStatusController.text.trim(),
      'externalActivities': _activitiesController.text.trim(),
    };
    if (_isAdultForm) {
      return {
        ...common,
        'occupation': _occupationController.text.trim(),
        'email': _emailController.text.trim(),
        'isMarried': ?_isMarried,
      };
    }
    return {
      ...common,
      'fatherJob': _fatherJobController.text.trim(),
      'motherJob': _motherJobController.text.trim(),
    };
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
            (p) =>
                UserOption(id: p.id!, fullName: p.fullName, avatar: p.avatar),
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
          if (widget.canSetHadithBooks) 'hadithBooks': _orderedHadithBooks,
          ..._registration(),
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
            isAdult: _isAdult,
            password: _isAdult ? _passwordController.text : null,
            hadithBooks: widget.canSetHadithBooks ? _orderedHadithBooks : null,
            registration: _registration(),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(StudentRepository.errorMessage(e))),
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
            validator: AccountValidators.fullName,
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
            label: 'العنوان',
            hint: 'أدخل العنوان',
            controller: _addressController,
            prefixIcon: const Icon(
              Icons.location_on_outlined,
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 24.h),
          const FormSectionHeader(
            icon: Icons.contact_phone_outlined,
            title: 'بيانات الاتصال',
          ),
          SizedBox(height: 16.h),
          AppTextField(
            label: 'رقم الهاتف *',
            hint: '05 51 23 45 67',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            prefixIcon: const Icon(
              Icons.phone_outlined,
              color: AppColors.onSurfaceVariant,
            ),
            validator: (v) => AccountValidators.phone(v, required: true),
          ),
          ContactOwnersHint(
            controller: _phoneController,
            field: ContactField.phone,
            excludeUserId: widget.student?.userId,
          ),
          SizedBox(height: 24.h),
          const FormSectionHeader(
            icon: Icons.school_outlined,
            title: 'استمارة التسجيل',
          ),
          SizedBox(height: 16.h),
          // Editing an existing person's role is out of scope — the backend
          // has no path for it — so the switch, and everything it changes,
          // only ever appears while creating.
          if (!_isEditing) ...[_buildAdultSwitch(), SizedBox(height: 16.h)],
          ..._buildRegistrationFields(),
          if (_isAdult) ...[
            AppTextField(
              label: 'كلمة المرور *',
              hint: '••••••••',
              controller: _passwordController,
              obscureText: true,
              prefixIcon: const Icon(
                Icons.lock_outline,
                color: AppColors.onSurfaceVariant,
              ),
              // Matches ChangePasswordSheet.validateNew rather than inventing
              // a second definition of "too short" for the same rule.
              validator: ChangePasswordSheet.validateNew,
            ),
            SizedBox(height: 4.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: AppText(
                'يسجّل الطالب الدخول بهذه الكلمة، ويمكنه تغييرها لاحقاً.',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: 16.h),
          ] else if (_parents.isNotEmpty) ...[
            UserSelectorField(
              label: 'ولي الأمر (اختياري)',
              hint: 'ابحث واختر ولي الأمر',
              searchHint: 'ابحث باسم ولي الأمر',
              emptyText: 'لا يوجد أولياء أمور',
              options: _parents,
              selectedId: _selectedParentId,
              onSelected: (o) => setState(() => _selectedParentId = o.id),
            ),
            SizedBox(height: 16.h),
          ],
          // Halaqa and the hadith track come last, after who the student is.
          const FormFieldLabel(label: 'الحلقة القرآنية (اختياري)'),
          SizedBox(height: 6.h),
          _buildHalaqaDropdown(),
          if (widget.canSetHadithBooks) ...[
            SizedBox(height: 16.h),
            _buildHadithBooks(),
          ],
        ],
      ),
    );
  }

  /// The switch on the left, the label filling the rest of the row — matches
  /// how every other toggle in the admin forms lays out under this app's
  /// deliberately-LTR tree (see `AppText`'s doc comment).
  Widget _buildAdultSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeThumbColor: AppColors.primary,
      value: _isAdult,
      onChanged: (v) => setState(() => _isAdult = v),
      title: AppText(
        'طالب بالغ',
        style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
        textAlign: TextAlign.end,
      ),
    );
  }

  /// The fields of the paper registration form (استمارة التسجيل) that the
  /// rest of this page does not already ask for: the children's form or the
  /// adults' one, following [_isAdultForm]. Name, birth date, address, phone
  /// and photo are above; the guardian is the parent picker below.
  List<Widget> _buildRegistrationFields() {
    Widget field(
      String label,
      TextEditingController controller,
      IconData icon, {
      TextInputType? keyboardType,
      String? Function(String?)? validator,
    }) {
      return Padding(
        padding: EdgeInsets.only(bottom: 16.h),
        child: AppTextField(
          label: label,
          controller: controller,
          keyboardType: keyboardType,
          prefixIcon: Icon(icon, color: AppColors.onSurfaceVariant),
          validator: validator,
        ),
      );
    }

    final health = field(
      _isAdultForm ? 'الحالة الصحية' : 'الحالة الصحية للطالب',
      _healthController,
      Icons.health_and_safety_outlined,
    );
    final familyStatus = field(
      'الحالة الاجتماعية للأسرة',
      _familyStatusController,
      Icons.family_restroom_outlined,
    );
    final activities = field(
      _isAdultForm
          ? 'توقيت النشاطات الخارجية (رياضة...) إن وجدت'
          : 'توقيت النشاطات الخارجية (رياضة، دعم مدرسي...) إن وجدت',
      _activitiesController,
      Icons.schedule_outlined,
    );

    if (_isAdultForm) {
      return [
        field(
          'المستوى الدراسي',
          _schoolLevelController,
          Icons.menu_book_outlined,
        ),
        field(
          'المهنة إن وجدت',
          _occupationController,
          Icons.work_outline,
        ),
        health,
        familyStatus,
        Padding(
          padding: EdgeInsets.only(bottom: 16.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                label: 'البريد الإلكتروني',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                prefixIcon: const Icon(
                  Icons.email_outlined,
                  color: AppColors.onSurfaceVariant,
                ),
                validator: AccountValidators.email,
              ),
              ContactOwnersHint(
                controller: _emailController,
                field: ContactField.email,
                excludeUserId: widget.student?.userId,
              ),
            ],
          ),
        ),
        activities,
        _buildMaritalStatus(),
        SizedBox(height: 16.h),
      ];
    }
    return [
      field('الصف الدراسي', _schoolLevelController, Icons.menu_book_outlined),
      health,
      familyStatus,
      field('مهنة الأب', _fatherJobController, Icons.work_outline),
      field('مهنة الأم', _motherJobController, Icons.work_outline),
      activities,
    ];
  }

  /// "هل أنت؟ أعزب / متزوج" from the adults' form. Left unanswered it stays
  /// null; tapping the chosen chip again clears it.
  Widget _buildMaritalStatus() {
    Widget chip(String label, bool value) => ChoiceChip(
      label: AppText(label, style: AppTextStyles.labelMd),
      selected: _isMarried == value,
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      onSelected: (on) => setState(() => _isMarried = on ? value : null),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const FormFieldLabel(label: 'الحالة الاجتماعية'),
        SizedBox(height: 6.h),
        Wrap(
          spacing: 8.w,
          children: [chip('متزوج', true), chip('أعزب', false)],
        ),
      ],
    );
  }

  /// The ticked books in list order, so the request reads the same way
  /// however the boxes were ticked.
  List<String> get _orderedHadithBooks =>
      kHadithBooks.where(_hadithBooks.contains).toList();

  /// Which hadith books this student memorizes — the teacher's recitation
  /// sheet offers only these, alongside Quran. Unlike [_buildAdultSwitch],
  /// this is meaningful on both create and edit, so it is not hidden behind
  /// `_isEditing`. Laid out like that switch: box on the left, label right.
  Widget _buildHadithBooks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const FormFieldLabel(label: 'حفظ الحديث (اختياري)'),
        for (final book in kHadithBooks)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppColors.primary,
            value: _hadithBooks.contains(book),
            onChanged: (on) => setState(
              () => on == true
                  ? _hadithBooks.add(book)
                  : _hadithBooks.remove(book),
            ),
            title: AppText(
              book,
              style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
              textAlign: TextAlign.end,
            ),
          ),
      ],
    );
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2012),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      locale: const Locale('fr'),
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
