import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';
import 'package:taqwa/features/data/repositories/student_repository.dart';
import 'package:taqwa/features/data/repositories/teacher_repository.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_selector_field.dart';

/// Builds the body sent to create or update a halaqa.
///
/// [studentIds] is dropped whenever [isEditing]: the update endpoint replaces
/// the halaqa's entire roster with whatever it is handed, and the edit form
/// never learns the current roster, so sending a partial list would disconnect
/// every student the admin did not re-pick. The picker is hidden on edit for
/// the same reason; this guard keeps the payload honest regardless.
@visibleForTesting
Map<String, dynamic> buildHalaqaPayload({
  required String name,
  required int teacherId,
  required String level,
  required List<int> studentIds,
  required bool isEditing,
}) {
  return <String, dynamic>{
    'name': name,
    'teacherId': teacherId,
    // An edit always sends the key so that emptying the field clears the
    // column; a create with a blank field leaves it out and keeps the NULL.
    if (isEditing || level.isNotEmpty) 'level': level.isEmpty ? null : level,
    if (!isEditing && studentIds.isNotEmpty) 'studentIds': studentIds,
  };
}

class CreateHalaqaPage extends StatefulWidget {
  /// Pass [editHalaqa] to pre-fill the form for editing an existing halaqa.
  const CreateHalaqaPage({super.key, this.editHalaqa});
  final HalaqaModel? editHalaqa;

  @override
  State<CreateHalaqaPage> createState() => _CreateHalaqaPageState();
}

class _CreateHalaqaPageState extends State<CreateHalaqaPage> {
  final _repo = HalaqaRepository();
  final _formKey = GlobalKey<FormState>();
  final _teacherRepository = TeacherRepository();
  final _studentRepository = StudentRepository();
  final _nameController = TextEditingController();
  final _levelController = TextEditingController();
  final _studentSearchController = TextEditingController();

  List<TeacherModel> _teachers = [];
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  final List<StudentModel> _selectedStudents = [];

  bool _isLoading = false;
  bool _isLoadingStudents = false;
  bool _showStudentDropdown = false;
  int? _selectedTeacherId;

  bool get _isEditing => widget.editHalaqa != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final h = widget.editHalaqa!;
      _nameController.text = h.name;
      _levelController.text = h.level ?? '';
      _selectedTeacherId = h.teacherId;
    }
    _loadTeachers();
    // Students back the create-only picker, so they are not needed on edit.
    if (!_isEditing) _loadStudents();
    _studentSearchController.addListener(_onSearchChanged);
  }

  Future<void> _loadTeachers() async {
    final result = await _teacherRepository.getAllTeachers();
    if (mounted) setState(() => _teachers = result);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final result = await _studentRepository.getAllStudents();
      if (mounted) {
        setState(() {
          _allStudents = result;
          _filteredStudents = result
              .where((s) => !_selectedStudents.any((sel) => sel.id == s.id))
              .toList();
        });
      }
    } catch (_) {
      // Students are optional; silently ignore errors
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  void _onSearchChanged() {
    final query = _studentSearchController.text.trim().toLowerCase();
    setState(() {
      _filteredStudents = _allStudents
          .where((s) =>
              !_selectedStudents.any((sel) => sel.id == s.id) &&
              s.fullName.toLowerCase().contains(query))
          .toList();
      _showStudentDropdown = true;
    });
  }

  void _addStudent(StudentModel student) {
    setState(() {
      _selectedStudents.add(student);
      _studentSearchController.clear();
      _showStudentDropdown = false;
      _filteredStudents = _allStudents
          .where((s) => !_selectedStudents.any((sel) => sel.id == s.id))
          .toList();
    });
  }

  void _removeStudent(StudentModel student) {
    setState(() {
      _selectedStudents.removeWhere((s) => s.id == student.id);
      _filteredStudents = _allStudents
          .where((s) => !_selectedStudents.any((sel) => sel.id == s.id))
          .toList();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المعلم')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = buildHalaqaPayload(
        name: _nameController.text.trim(),
        teacherId: _selectedTeacherId!,
        level: _levelController.text.trim(),
        studentIds:
            _selectedStudents.map((s) => s.id).whereType<int>().toList(),
        isEditing: _isEditing,
      );

      if (_isEditing) {
        await _repo.updateHalaqa(widget.editHalaqa!.id, data);
      } else {
        await _repo.createHalaqa(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing ? 'تم تحديث بيانات الحلقة' : 'تم إضافة الحلقة بنجاح',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(HalaqaRepository.errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _levelController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_showStudentDropdown) {
          setState(() => _showStudentDropdown = false);
        }
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(height: 24.h),
                        // ── Main card ──────────────────────────────────────
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionHeader(
                                icon: Icons.menu_book_outlined,
                                title: 'بيانات الحلقة',
                              ),
                              SizedBox(height: 16.h),
                              // Name
                              _FieldLabel(label: 'اسم الحلقة *'),
                              SizedBox(height: 6.h),
                              AppTextField(
                                hint: 'أدخل اسم الحلقة',
                                controller: _nameController,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'يرجى إدخال اسم الحلقة';
                                  }
                                  return null;
                                },
                                prefixIcon: const Icon(
                                  Icons.menu_book_outlined,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              // Level
                              _FieldLabel(label: 'المستوى'),
                              SizedBox(height: 6.h),
                              AppTextField(
                                hint: 'مثال: مبتدئ',
                                controller: _levelController,
                                validator: (v) {
                                  // Mirrors the column's VarChar(100), so the
                                  // admin sees the limit before the request.
                                  if ((v ?? '').trim().length > 100) {
                                    return 'المستوى يجب ألا يتجاوز 100 حرف';
                                  }
                                  return null;
                                },
                                prefixIcon: const Icon(
                                  Icons.stairs_outlined,
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(height: 16.h),
                              // Teacher
                              UserSelectorField(
                                label: 'المعلم المسؤول *',
                                hint: 'اختر المعلم',
                                searchHint: 'ابحث باسم المعلم',
                                emptyText: 'لا يوجد معلم مطابق',
                                options: _teachers
                                    .map(
                                      (t) => UserOption(
                                        id: t.id,
                                        fullName: t.fullName,
                                        avatar: t.avatar,
                                      ),
                                    )
                                    .toList(),
                                selectedId: _selectedTeacherId,
                                onSelected: (o) => setState(
                                    () => _selectedTeacherId = o.id),
                              ),
                            ],
                          ),
                        ),
                        // The student picker is create-only. On update the API
                        // replaces the whole roster with whatever `studentIds`
                        // contains, and the form has no way to know the current
                        // roster (see the note on HalaqaModel.students), so
                        // sending it here would disconnect every student the
                        // admin did not re-pick.
                        if (!_isEditing) ...[
                          SizedBox(height: 20.h),
                          // ── Students card ──────────────────────────────────
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    if (_selectedStudents.isNotEmpty)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                              AppConstants.radiusFull),
                                        ),
                                        child: Text(
                                          '${_selectedStudents.length} طلاب',
                                          style:
                                              AppTextStyles.labelSm.copyWith(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    if (_selectedStudents.isNotEmpty)
                                      SizedBox(width: 8.w),
                                    _SectionHeader(
                                      icon: Icons.people_outline,
                                      title: 'الطلاب (اختياري)',
                                    ),
                                  ],
                                ),
                                SizedBox(height: 4.h),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text(
                                    'ابحث عن طالب وأضفه إلى الحلقة',
                                    style: AppTextStyles.labelSm.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 12.h),
                                // ── Search box ───────────────────────────────
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd),
                                    border: Border.all(
                                      color: _showStudentDropdown
                                          ? AppColors.primary
                                          : AppColors.inputBorder,
                                      width: _showStudentDropdown ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _studentSearchController,
                                          textAlign: TextAlign.start,
                                          textDirection: TextDirection.rtl,
                                          style: AppTextStyles.bodyMd,
                                          onTap: () => setState(
                                              () => _showStudentDropdown = true),
                                          decoration: InputDecoration(
                                            hintText: 'ابحث عن طالب بالاسم...',
                                            hintStyle: AppTextStyles.labelMd
                                                .copyWith(
                                              color: AppColors.inputPlaceholder,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: 16.w,
                                              vertical: 14.h,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.only(left: 12.w),
                                        child: _isLoadingStudents
                                            ? SizedBox(
                                                width: 18.w,
                                                height: 18.w,
                                                child:
                                                    const CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: AppColors.primary,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.search,
                                                color: AppColors.primary,
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                                // ── Dropdown results inline (takes normal space) ──
                                if (_showStudentDropdown &&
                                    _filteredStudents.isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Container(
                                    constraints:
                                        BoxConstraints(maxHeight: 220.h),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.radiusMd),
                                      border: Border.all(
                                          color: AppColors.outlineVariant),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(18, 52, 59, 0.06),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.symmetric(
                                          vertical: 4.h),
                                      separatorBuilder: (context, index) =>
                                          Divider(
                                        height: 1,
                                        color: AppColors.outlineVariant,
                                      ),
                                      itemCount: _filteredStudents.length,
                                      itemBuilder: (ctx, i) {
                                        final s = _filteredStudents[i];
                                        return InkWell(
                                          onTap: () => _addStudent(s),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 12.w,
                                              vertical: 10.h,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    s.fullName,
                                                    style: AppTextStyles.bodyMd
                                                        .copyWith(
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                    textAlign: TextAlign.start,
                                                  ),
                                                ),
                                                SizedBox(width: 10.w),
                                                StudentAvatar(
                                                  avatarUrl: s.avatar,
                                                  name: s.fullName,
                                                  size: 36.w,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                                if (_showStudentDropdown &&
                                    _filteredStudents.isEmpty &&
                                    _studentSearchController.text.isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                          AppConstants.radiusMd),
                                      border: Border.all(
                                          color: AppColors.outlineVariant),
                                    ),
                                    child: Text(
                                      'لا يوجد طلاب مطابقون',
                                      style: AppTextStyles.labelMd.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                                // ── Selected students cards ───────────────────
                                if (_selectedStudents.isNotEmpty) ...[
                                  SizedBox(height: 16.h),
                                  ..._selectedStudents.map(
                                    (s) => Padding(
                                      padding: EdgeInsets.only(bottom: 8.h),
                                      child: SelectedStudentCard(
                                        student: s,
                                        onRemove: () => _removeStudent(s),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                        SizedBox(height: 24.h),
                        AppButton(
                          label: _isEditing ? 'حفظ التعديلات' : 'إضافة حلقة',
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
          Icon(Icons.home, color: AppColors.primary, size: 22.w),
          SizedBox(width: 8.w),
          Text(
            'تقوى',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

// ─── Selected student chip card ────────────────────────────────────────────

class SelectedStudentCard extends StatelessWidget {
  const SelectedStudentCard({
    super.key,
    required this.student,
    required this.onRemove,
  });
  final StudentModel student;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          // Remove button
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 14.w,
                color: AppColors.error,
              ),
            ),
          ),
          const Spacer(),
          // Name
          Flexible(
            child: Text(
              student.fullName,
              style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.start,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          // Avatar
          StudentAvatar(
            avatarUrl: student.avatar,
            name: student.fullName,
            size: 38.w,
          ),
        ],
      ),
    );
  }
}

// ─── Avatar widget ─────────────────────────────────────────────────────────

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 40,
  });
  final String? avatarUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0]).join()
        : '؟';

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: AppColors.surfaceContainerHigh,
        onBackgroundImageError: (p0, p1) {},
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: Text(
        initials,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.3,
        ),
      ),
    );
  }
}

// ─── Shared helpers ────────────────────────────────────────────────────────

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
      mainAxisAlignment: MainAxisAlignment.start,
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
