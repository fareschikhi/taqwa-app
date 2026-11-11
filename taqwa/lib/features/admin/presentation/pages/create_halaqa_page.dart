import 'package:flutter/material.dart';
import 'package:taqwa/core/utils/search_text.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/models/teacher/teacher_model.dart';
import 'package:taqwa/features/data/models/student/student_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_repository.dart';
import 'package:taqwa/features/data/repositories/student_repository.dart';
import 'package:taqwa/features/data/repositories/teacher_repository.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/halaqa_levels.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/user_selector_field.dart';
import '../../../../core/widgets/confirm_second_halaqa_dialog.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Builds the body sent to create or update a halaqa.
///
/// On edit, [studentIds] travels only when [rosterLoaded]: the update endpoint
/// replaces the halaqa's entire roster with whatever it is handed, so a list
/// built without first knowing the current roster would disconnect every
/// student the admin never saw. Once the roster is known the list is sent
/// even when empty — that is how removing the last student is saved.
///
/// [isAdult] always travels — false is as meaningful an answer as true, and
/// the backend's `UpdateHalaqaDto` accepts it either way. The three rates
/// only travel alongside `isAdult: true`: a child's halaqa never charges
/// anything, so sending zeros (or any number) for it would be dead data a
/// future reader would have to explain, not a real setting.
@visibleForTesting
Map<String, dynamic> buildHalaqaPayload({
  required String name,
  required int teacherId,
  required String level,
  required List<int> studentIds,
  required bool isEditing,
  bool rosterLoaded = false,
  bool isAdult = false,
  int? absenceFee,
  int? lateFee,
  int? missedMemorizationFee,
}) {
  return <String, dynamic>{
    'name': name,
    'teacherId': teacherId,
    // One of kHalaqaLevels: the form will not submit without a pick.
    'level': level,
    if (isEditing ? rosterLoaded : studentIds.isNotEmpty)
      'studentIds': studentIds,
    'isAdult': isAdult,
    if (isAdult && absenceFee != null) 'absenceFee': absenceFee,
    if (isAdult && lateFee != null) 'lateFee': lateFee,
    if (isAdult && missedMemorizationFee != null)
      'missedMemorizationFee': missedMemorizationFee,
  };
}

/// The halaqas [selectedTeacherId] already runs, ignoring the one being
/// edited. Empty means this save asks nothing of her that needs confirming.
///
/// The school's norm is one halaqa per teacher, so a non-empty result is what
/// the confirmation dialog exists for — it both decides that a dialog is owed
/// and supplies the names it lists.
///
/// Keeping a halaqa's existing teacher returns empty even when she is already
/// over the norm: renaming a halaqa or editing its fees moves nobody, and a
/// dialog on every such save would train the admin to dismiss it unread. Only
/// a save that actually hands her a halaqa she does not already have asks.
@visibleForTesting
List<String> otherHalaqasOf({
  required int? selectedTeacherId,
  required int? currentTeacherId,
  required int? editingHalaqaId,
  required List<HalaqaModel> allHalaqas,
}) {
  if (selectedTeacherId == null) return const [];
  if (selectedTeacherId == currentTeacherId) return const [];

  return allHalaqas
      .where((h) => h.teacherId == selectedTeacherId)
      // The row under edit is about to become hers by this very save, so it
      // is never evidence that she already had a halaqa.
      .where((h) => h.id != editingHalaqaId)
      .map((h) => h.name)
      .toList();
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
  final _studentSearchController = TextEditingController();
  final _absenceFeeController = TextEditingController();
  final _lateFeeController = TextEditingController();
  final _missedMemorizationFeeController = TextEditingController();

  List<TeacherModel> _teachers = [];

  /// Every halaqa in the school, used only to work out whether the picked
  /// teacher already runs one. The admin's own `GET /halaqas` is unfiltered,
  /// so this needs nothing from the teachers endpoint — which a teacher can
  /// also read, and which must not start carrying colleagues' halaqa names.
  List<HalaqaModel> _allHalaqas = [];
  List<StudentModel> _allStudents = [];
  List<StudentModel> _filteredStudents = [];
  final List<StudentModel> _selectedStudents = [];

  bool _isLoading = false;
  bool _isLoadingStudents = false;
  bool _showStudentDropdown = false;
  bool _isAdultHalaqa = false;
  int? _selectedTeacherId;

  /// One of [kHalaqaLevels]. A halaqa saved back when the level was free
  /// text (e.g. "مبتدئ") opens with nothing picked, so the admin has to
  /// choose a real category before the edit can be saved.
  String? _selectedLevel;

  /// On edit, [_selectedStudents] starts as the halaqa's current roster. Until
  /// that roster has arrived the picker stays hidden and the save sends no
  /// `studentIds`, so a slow or failed load can never disconnect anyone.
  bool _isLoadingRoster = false;
  bool _rosterLoaded = false;
  bool _rosterFailed = false;

  bool get _isEditing => widget.editHalaqa != null;
  bool get _canPickStudents => !_isEditing || _rosterLoaded;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final h = widget.editHalaqa!;
      _nameController.text = h.name;
      _selectedLevel = kHalaqaLevels.contains(h.level) ? h.level : null;
      _selectedTeacherId = h.teacherId;
      _isAdultHalaqa = h.isAdult;
      _absenceFeeController.text = h.absenceFee.toString();
      _lateFeeController.text = h.lateFee.toString();
      _missedMemorizationFeeController.text = h.missedMemorizationFee
          .toString();
    }
    _loadTeachers();
    _loadHalaqas();
    _loadStudents();
    if (_isEditing) _loadRoster();
    _studentSearchController.addListener(_onSearchChanged);
  }

  Future<void> _loadRoster() async {
    setState(() {
      _isLoadingRoster = true;
      _rosterFailed = false;
    });
    try {
      final roster = await _repo.getHalaqaRoster(widget.editHalaqa!.id);
      if (!mounted) return;
      setState(() {
        _selectedStudents
          ..clear()
          ..addAll(roster);
        _rosterLoaded = true;
        _filteredStudents = _eligibleStudents(_studentSearchController.text);
      });
    } catch (_) {
      if (mounted) setState(() => _rosterFailed = true);
    } finally {
      if (mounted) setState(() => _isLoadingRoster = false);
    }
  }

  Future<void> _loadTeachers() async {
    final result = await _teacherRepository.getAllTeachers();
    if (mounted) setState(() => _teachers = result);
  }

  Future<void> _loadHalaqas() async {
    final result = await _repo.getAllHalaqas();
    if (mounted) setState(() => _allHalaqas = result);
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final result = await _studentRepository.getAllStudents();
      if (mounted) {
        setState(() {
          _allStudents = result;
          _filteredStudents = _eligibleStudents(_studentSearchController.text);
        });
      }
    } catch (_) {
      // Students are optional; silently ignore errors
    } finally {
      if (mounted) setState(() => _isLoadingStudents = false);
    }
  }

  /// An adults' halaqa can only enrol adult students and vice versa — the
  /// backend rejects the mismatch outright — so the picker filters by
  /// [_isAdultHalaqa] rather than ever offering a student who can't actually
  /// be added.
  List<StudentModel> _eligibleStudents(String query) {
    return _allStudents
        .where((s) => s.isAdult == _isAdultHalaqa)
        .where((s) => !_selectedStudents.any((sel) => sel.id == s.id))
        .where((s) => matchesSearch(query, [s.fullName]))
        .toList();
  }

  /// Switching the halaqa's type invalidates whatever was already picked
  /// under the old one, so the selection is cleared rather than left to
  /// either violate the adult/child pairing or silently vanish from the
  /// payload without the admin noticing why. On edit that selection is the
  /// halaqa's real roster, so clearing it is confirmed first.
  Future<void> _onToggleAdultHalaqa(bool value) async {
    if (_isEditing && _selectedStudents.isNotEmpty) {
      final confirmed = await ConfirmDeleteDialog.show(
        context,
        title: 'تغيير نوع الحلقة',
        message:
            'سيتم إزالة ${_selectedStudents.length} من الطلاب من الحلقة '
            'لأنهم لا يناسبون النوع الجديد. '
            'لن يُحفظ التغيير إلا بعد الضغط على حفظ التعديلات.',
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _isAdultHalaqa = value;
      _selectedStudents.clear();
      _filteredStudents = _eligibleStudents(_studentSearchController.text);
    });
  }

  void _onSearchChanged() {
    setState(() {
      _filteredStudents = _eligibleStudents(_studentSearchController.text);
      _showStudentDropdown = true;
    });
  }

  void _addStudent(StudentModel student) {
    setState(() {
      _selectedStudents.add(student);
      _studentSearchController.clear();
      _showStudentDropdown = false;
      _filteredStudents = _eligibleStudents('');
    });
  }

  void _removeStudent(StudentModel student) {
    setState(() {
      _selectedStudents.removeWhere((s) => s.id == student.id);
      _filteredStudents = _eligibleStudents(_studentSearchController.text);
    });
  }

  /// Parses a rate field defensively: the admin can type anything, and the
  /// field's own validator has already rejected a non-numeric or negative
  /// entry by the time this runs, so a failed parse here is unreachable in
  /// practice — but returning null rather than throwing keeps a bad entry a
  /// validation message, never a crash.
  int? _parseRate(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTeacherId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('يرجى اختيار المعلم')));
      return;
    }

    // One halaqa per teacher is the norm, and a second is allowed only if the
    // admin means it. Nothing on the server enforces this: it is a judgement
    // about staffing, not a data rule, so the halaqa stays saveable either way
    // and the check lives at the point where a person can answer for it.
    final alsoRuns = otherHalaqasOf(
      selectedTeacherId: _selectedTeacherId,
      currentTeacherId: widget.editHalaqa?.teacherId,
      editingHalaqaId: widget.editHalaqa?.id,
      allHalaqas: _allHalaqas,
    );
    if (alsoRuns.isNotEmpty) {
      // The picker is built from `_teachers`, so a miss here means the list
      // had not arrived yet; the prompt still has to read as a sentence.
      final match = _teachers.where((t) => t.id == _selectedTeacherId);
      final confirmed = await ConfirmSecondHalaqaDialog.show(
        context,
        teacherName: match.isEmpty ? 'هذا المعلم' : match.first.fullName,
        existingHalaqas: alsoRuns,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _isLoading = true);

    try {
      final data = buildHalaqaPayload(
        name: _nameController.text.trim(),
        teacherId: _selectedTeacherId!,
        // validate() above refuses to get here without a pick.
        level: _selectedLevel!,
        studentIds: _selectedStudents
            .map((s) => s.id)
            .whereType<int>()
            .toList(),
        isEditing: _isEditing,
        rosterLoaded: _rosterLoaded,
        isAdult: _isAdultHalaqa,
        absenceFee: _isAdultHalaqa ? _parseRate(_absenceFeeController) : null,
        lateFee: _isAdultHalaqa ? _parseRate(_lateFeeController) : null,
        missedMemorizationFee: _isAdultHalaqa
            ? _parseRate(_missedMemorizationFeeController)
            : null,
      );

      if (_isEditing) {
        await _repo.updateHalaqa(widget.editHalaqa!.id, data);
      } else {
        await _repo.createHalaqa(data);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isEditing ? 'تم تحديث بيانات الحلقة' : 'تم إضافة الحلقة بنجاح',
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(HalaqaRepository.errorMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _studentSearchController.dispose();
    _absenceFeeController.dispose();
    _lateFeeController.dispose();
    _missedMemorizationFeeController.dispose();
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
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        SizedBox(height: 24.h),
                        // ── Main card ──────────────────────────────────────
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusXl,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 40, 0, 0.04),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
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
                              _FieldLabel(label: 'المستوى *'),
                              SizedBox(height: 6.h),
                              _buildLevelPicker(),
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
                                onSelected: (o) =>
                                    setState(() => _selectedTeacherId = o.id),
                              ),
                              SizedBox(height: 8.h),
                              _buildAdultHalaqaSwitch(),
                              if (_isAdultHalaqa) ...[
                                SizedBox(height: 12.h),
                                _FieldLabel(label: 'رسوم الغياب *'),
                                SizedBox(height: 6.h),
                                AppTextField(
                                  hint: '0',
                                  controller: _absenceFeeController,
                                  keyboardType: TextInputType.number,
                                  validator: _validateRate,
                                  prefixIcon: const Icon(
                                    Icons.event_busy_outlined,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                _FieldLabel(label: 'رسوم التأخر *'),
                                SizedBox(height: 6.h),
                                AppTextField(
                                  hint: '0',
                                  controller: _lateFeeController,
                                  keyboardType: TextInputType.number,
                                  validator: _validateRate,
                                  prefixIcon: const Icon(
                                    Icons.timer_outlined,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                                SizedBox(height: 16.h),
                                _FieldLabel(label: 'رسوم عدم الحفظ *'),
                                SizedBox(height: 6.h),
                                AppTextField(
                                  hint: '0',
                                  controller: _missedMemorizationFeeController,
                                  keyboardType: TextInputType.number,
                                  validator: _validateRate,
                                  prefixIcon: const Icon(
                                    Icons.menu_book_outlined,
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // On edit this card opens on the current roster, and
                        // the save sends the edited list in full: the update
                        // endpoint replaces the roster with whatever it gets.
                        SizedBox(height: 20.h),
                        // ── Students card ──────────────────────────────────
                        Container(
                          padding: EdgeInsets.all(20.w),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusXl,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color.fromRGBO(0, 40, 0, 0.04),
                                blurRadius: 20,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  if (_selectedStudents.isNotEmpty)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppConstants.radiusFull,
                                        ),
                                      ),
                                      child: AppText(
                                        '${_selectedStudents.length} طلاب',
                                        style: AppTextStyles.labelSm.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  if (_selectedStudents.isNotEmpty)
                                    SizedBox(width: 8.w),
                                  _SectionHeader(
                                    icon: Icons.people_outline,
                                    title: _isEditing
                                        ? 'طلاب الحلقة'
                                        : 'الطلاب (اختياري)',
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: AppText(
                                  _isEditing
                                      ? 'أضف طالباً أو احذفه، وتُحفظ التغييرات عند الضغط على حفظ التعديلات'
                                      : 'ابحث عن طالب وأضفه إلى الحلقة',
                                  style: AppTextStyles.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              if (_isEditing && _isLoadingRoster)
                                Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16.h),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                              if (_isEditing && _rosterFailed)
                                _RosterErrorBox(onRetry: _loadRoster),
                              if (_canPickStudents) ...[
                                // ── Search box ───────────────────────────────
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainerLowest,
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusMd,
                                    ),
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
                                          textAlign: TextAlign.right,
                                          textDirection: TextDirection.rtl,
                                          style: AppTextStyles.bodyMd,
                                          onTap: () => setState(
                                            () => _showStudentDropdown = true,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'ابحث عن طالب بالاسم...',
                                            hintStyle: AppTextStyles.labelMd
                                                .copyWith(
                                                  color: AppColors
                                                      .inputPlaceholder,
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
                                    constraints: BoxConstraints(
                                      maxHeight: 220.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppColors.outlineVariant,
                                      ),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(
                                            0,
                                            40,
                                            0,
                                            0.06,
                                          ),
                                          blurRadius: 10,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.symmetric(
                                        vertical: 4.h,
                                      ),
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
                                                  child: AppText(
                                                    s.fullName,
                                                    style: AppTextStyles.bodyMd
                                                        .copyWith(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                    textAlign: TextAlign.end,
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
                                    _studentSearchController
                                        .text
                                        .isNotEmpty) ...[
                                  SizedBox(height: 8.h),
                                  Container(
                                    width: double.infinity,
                                    padding: EdgeInsets.all(14.w),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceContainerLowest,
                                      borderRadius: BorderRadius.circular(
                                        AppConstants.radiusMd,
                                      ),
                                      border: Border.all(
                                        color: AppColors.outlineVariant,
                                      ),
                                    ),
                                    child: AppText(
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
                                        removeIcon: _isEditing
                                            ? Icons.delete_outline
                                            : Icons.close,
                                        removeTooltip: _isEditing
                                            ? 'حذف من الحلقة'
                                            : 'إزالة',
                                      ),
                                    ),
                                  ),
                                ] else if (_isEditing) ...[
                                  SizedBox(height: 16.h),
                                  Center(
                                    child: AppText(
                                      'لا يوجد طلاب في هذه الحلقة',
                                      style: AppTextStyles.labelMd.copyWith(
                                        color: AppColors.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
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

  /// The four categories as chips, styled like the student form's chips. A
  /// [FormField] so the form's single validate() call also checks this one
  /// and shows the error under it. RTL so the list reads ابتدائي → جامعي from
  /// the right and a wrapped second line stays right-aligned.
  Widget _buildLevelPicker() {
    return FormField<String>(
      initialValue: _selectedLevel,
      validator: (v) => v == null ? 'يرجى اختيار مستوى الحلقة' : null,
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Wrap(
            textDirection: TextDirection.rtl,
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              for (final level in kHalaqaLevels)
                ChoiceChip(
                  label: AppText(level, style: AppTextStyles.labelMd),
                  selected: _selectedLevel == level,
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  onSelected: (_) {
                    setState(() => _selectedLevel = level);
                    field.didChange(level);
                  },
                ),
            ],
          ),
          if (field.hasError) ...[
            SizedBox(height: 6.h),
            AppText(
              field.errorText!,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
            ),
          ],
        ],
      ),
    );
  }

  /// The switch on the left, the label filling the rest of the row — matches
  /// how every other toggle in the admin forms lays out under this app's
  /// deliberately-LTR tree (see `AppText`'s doc comment).
  Widget _buildAdultHalaqaSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      activeThumbColor: AppColors.primary,
      value: _isAdultHalaqa,
      onChanged: _onToggleAdultHalaqa,
      title: AppText(
        'حلقة الكبار',
        style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurface),
        textAlign: TextAlign.end,
      ),
    );
  }

  /// A rate is a whole number of dinars, and 0 is a legitimate answer — a
  /// halaqa may fine absence but not lateness — so the floor is 0, not 1.
  /// An admin can type anything into the field, so a bad entry must surface
  /// here as a message rather than reach `int.parse` and crash.
  String? _validateRate(String? v) {
    final text = (v ?? '').trim();
    if (text.isEmpty) return 'يرجى إدخال القيمة';
    final n = int.tryParse(text);
    if (n == null) return 'يرجى إدخال رقم صحيح';
    if (n < 0) return 'يجب ألا تقل القيمة عن 0';
    return null;
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
    this.removeIcon = Icons.close,
    this.removeTooltip = 'إزالة',
  });
  final StudentModel student;
  final VoidCallback onRemove;
  final IconData removeIcon;
  final String removeTooltip;

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
          Tooltip(
            message: removeTooltip,
            child: Semantics(
              button: true,
              label: removeTooltip,
              child: InkResponse(
                onTap: onRemove,
                radius: 20.w,
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(removeIcon, size: 16.w, color: AppColors.error),
                ),
              ),
            ),
          ),
          const Spacer(),
          // Name
          Flexible(
            child: AppText(
              student.fullName,
              style: AppTextStyles.bodyMd.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.end,
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
        backgroundImage: NetworkImage(ApiEndpoints.mediaUrl(avatarUrl!)),
        backgroundColor: AppColors.surfaceContainerHigh,
        onBackgroundImageError: (p0, p1) {},
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primary.withValues(alpha: 0.15),
      child: AppText(
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

class _RosterErrorBox extends StatelessWidget {
  const _RosterErrorBox({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          AppText(
            'تعذر تحميل طلاب الحلقة',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.error),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4.h),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            label: AppText(
              'إعادة المحاولة',
              style: AppTextStyles.labelMd.copyWith(color: AppColors.primary),
            ),
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
  Widget build(BuildContext context) => AppText(
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
