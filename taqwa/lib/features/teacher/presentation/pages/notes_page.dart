import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/models/student_note_model.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _noteController = TextEditingController();
  TeacherStudentModel? _selectedStudent;
  bool _showForm = false;
  bool _isSaving = false;
  bool _isLoading = true;

  List<TeacherStudentModel> _students = [];
  List<StudentNoteModel> _notes = [];

  final _repo = TeacherRepository();

  int? get _teacherId => ref.read(authProvider).user?.teacherId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    final tid = _teacherId;
    if (tid == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repo.getStudents(teacherId: tid, limit: 100),
        _repo.getNotesByTeacher(tid),
      ]);
      setState(() {
        _students = (results[0] as StudentListResponse).data;
        _notes = results[1] as List<StudentNoteModel>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    final tid = _teacherId;
    if (tid == null || _selectedStudent == null) return;
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final newNote = await _repo.createNote(
        studentId: _selectedStudent!.id,
        teacherId: tid,
        note: text,
      );
      setState(() {
        _notes = [newNote, ..._notes];
        _showForm = false;
        _selectedStudent = null;
        _noteController.clear();
        _isSaving = false;
      });
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteNote(int noteId) async {
    try {
      await _repo.deleteNote(noteId);
      setState(() => _notes.removeWhere((n) => n.id == noteId));
    } catch (_) {}
  }

  Future<void> _pickStudent() async {
    String query = '';
    final selected = await showModalBottomSheet<TeacherStudentModel>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = _students
                .where(
                  (s) =>
                      s.fullName.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16.w,
                  right: 16.w,
                  top: 16.h,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 16.h,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'اختر الطالب',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      autofocus: true,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: AppTextStyles.bodyMd,
                      onChanged: (v) => setSheetState(() => query = v),
                      decoration: InputDecoration(
                        hintText: 'ابحث باسم الطالب...',
                        hintStyle: AppTextStyles.labelMd.copyWith(
                          color: AppColors.inputPlaceholder,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: AppColors.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceContainerLow,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.inputBorder,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          borderSide: const BorderSide(
                            color: AppColors.inputFocusBorder,
                            width: 1.5,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 12.h,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 320.h),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.h),
                              child: Text(
                                'لا يوجد طلاب مطابقون',
                                style: AppTextStyles.bodyMd.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Divider(
                                height: 1,
                                color: AppColors.outlineVariant,
                              ),
                              itemBuilder: (_, i) {
                                final s = filtered[i];
                                return ListTile(
                                  title: Text(
                                    s.fullName,
                                    style: AppTextStyles.bodyMd,
                                    textAlign: TextAlign.end,
                                  ),
                                  onTap: () => Navigator.pop(ctx, s),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected != null) setState(() => _selectedStudent = selected);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null && _students.isEmpty && !_isLoading) {
        _loadData();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadData,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Header
                    Padding(
                      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.notifications_outlined,
                                color: AppColors.onSurfaceVariant,
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
                          SizedBox(height: 16.h),
                          SizedBox(
                            height: 44.h,
                            child: AppButton(
                              label: 'إضافة ملاحظة',
                              variant: AppButtonVariant.gradient,
                              icon: Icons.add,
                              height: 44.h,
                              onPressed: () =>
                                  setState(() => _showForm = !_showForm),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Add note form
                    if (_showForm) ...[
                      SizedBox(height: 12.h),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 16.w),
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusXl,
                          ),
                          border: Border.all(color: AppColors.primaryContainer),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(18, 52, 59, 0.06),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'ملاحظة جديدة',
                              style: AppTextStyles.headlineSm.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            GestureDetector(
                              onTap: _pickStudent,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  border: Border.all(
                                    color: AppColors.inputBorder,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 14.h,
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.primary,
                                    ),
                                    Expanded(
                                      child: Text(
                                        _selectedStudent?.fullName ??
                                            'اختر الطالب...',
                                        style: AppTextStyles.labelMd.copyWith(
                                          color: _selectedStudent != null
                                              ? AppColors.onSurface
                                              : AppColors.inputPlaceholder,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            TextField(
                              controller: _noteController,
                              maxLines: 3,
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: AppTextStyles.bodyMd,
                              decoration: InputDecoration(
                                hintText: 'اكتب ملاحظتك هنا...',
                                hintStyle: AppTextStyles.labelMd.copyWith(
                                  color: AppColors.inputPlaceholder,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceContainerLow,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputBorder,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppConstants.radiusMd,
                                  ),
                                  borderSide: const BorderSide(
                                    color: AppColors.inputFocusBorder,
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: EdgeInsets.all(12.w),
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Row(
                              children: [
                                Expanded(
                                  child: AppButton(
                                    label: 'إلغاء',
                                    variant: AppButtonVariant.secondary,
                                    height: 40.h,
                                    onPressed: () =>
                                        setState(() => _showForm = false),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: AppButton(
                                    label: 'حفظ',
                                    variant: AppButtonVariant.primary,
                                    height: 40.h,
                                    isLoading: _isSaving,
                                    onPressed: _saveNote,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: 16.h),
                    Expanded(
                      child: _notes.isEmpty
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: 300.h,
                                alignment: Alignment.center,
                                child: Text(
                                  'لا توجد ملاحظات بعد',
                                  style: AppTextStyles.bodyMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            )
                          : ListView.separated(
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 16.w),
                              itemCount: _notes.length,
                              separatorBuilder: (context, index) =>
                                  SizedBox(height: 16.h),
                              itemBuilder: (_, i) => _NoteCard(
                                note: _notes[i],
                                onDelete: () => _deleteNote(_notes[i].id),
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note, required this.onDelete});
  final StudentNoteModel note;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = (note.studentName?.isNotEmpty ?? false)
        ? note.studentName![0]
        : '؟';
    final colors = [
      AppColors.primaryContainer,
      AppColors.tertiaryContainer,
      AppColors.secondaryContainer,
    ];
    final bgColor = colors[note.id % colors.length];

    String displayDate = '';
    try {
      final dt = DateTime.parse(note.createdAt);
      displayDate = '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      displayDate = note.createdAt;
    }

    return Container(
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
          // Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(AppConstants.radiusXl),
                topLeft: Radius.circular(AppConstants.radiusXl),
              ),
            ),
            child: Row(
              children: [
                Text(
                  displayDate,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  note.studentName ?? '',
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(width: 10.w),
                Container(
                  width: 32.w,
                  height: 32.w,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      initial,
                      style: AppTextStyles.labelMdBold.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  note.note,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                    height: 1.7,
                  ),
                  textAlign: TextAlign.end,
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () async {
                        final confirmed = await ConfirmDeleteDialog.show(
                          context,
                          title: 'حذف الملاحظة',
                          message:
                              'هل أنت متأكد من حذف هذه الملاحظة؟ لا يمكن التراجع عن هذا الإجراء.',
                        );
                        if (confirmed) onDelete();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                            size: 18,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'حذف',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
