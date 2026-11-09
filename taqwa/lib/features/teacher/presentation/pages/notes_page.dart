import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/confirm_delete_dialog.dart';
import '../../../../core/widgets/expandable_text.dart';
import '../../../../core/widgets/note_timeline.dart' show kNoteFoldedLines;
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/selected_halaqa_provider.dart';
import '../../../data/repositories/teacher_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/models/student_note_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final _noteController = TextEditingController();
  // The students the note goes to; several are sent one shared note.
  Set<int> _selectedIds = {};
  // The note the form is rewriting; null while it writes a new one.
  StudentNoteModel? _editingNote;
  bool _showForm = false;
  bool _isSaving = false;
  bool _isLoading = true;

  // Every halaqa's students and notes, loaded once; a halaqa switch only
  // changes which of them [_students] and [_notes] let through.
  List<TeacherStudentModel> _roster = [];
  List<StudentNoteModel> _allNotes = [];

  /// The halaqa picked in the shell's switcher: the students the picker
  /// offers, and the ones "all students" addresses.
  List<TeacherStudentModel> get _students {
    final selected = ref.read(selectedHalaqaProvider).selected;
    return _roster
        .where((s) => inSelectedHalaqa(s.halaqaId, selected))
        .toList();
  }

  /// Notes addressed to anyone in that halaqa. A note sent to several
  /// halaqas before the switcher existed shows under each of them.
  List<StudentNoteModel> get _notes {
    if (ref.read(selectedHalaqaProvider).selected == null) return _allNotes;
    final ids = _students.map((s) => s.id).toSet();
    return _allNotes.where((n) {
      final recipients = n.recipientIds.isEmpty
          ? [n.studentId]
          : n.recipientIds;
      return recipients.any(ids.contains);
    }).toList();
  }

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
        _roster = (results[0] as StudentListResponse).data;
        _allNotes = results[1] as List<StudentNoteModel>;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNote() async {
    if (_editingNote != null) return _saveEdit(_editingNote!);
    final tid = _teacherId;
    if (tid == null) return;
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final text = _noteController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      final newNote = ids.length > 1
          ? await _repo.createBulkNote(
              studentIds: ids,
              teacherId: tid,
              note: text,
            )
          : await _repo.createNote(
              studentId: ids.single,
              teacherId: tid,
              note: text,
            );
      setState(() {
        _allNotes = [newNote, ..._allNotes];
        _showForm = false;
        _selectedIds = {};
        _noteController.clear();
        _isSaving = false;
      });
    } catch (_) {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _saveEdit(StudentNoteModel original) async {
    final text = _noteController.text.trim();
    if (text.isEmpty) return;
    if (text == original.note) {
      _closeForm();
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updated = await _repo.updateNote(id: original.id, note: text);
      setState(() {
        _allNotes = [
          for (final n in _allNotes) n.id == updated.id ? updated : n,
        ];
        _isSaving = false;
      });
      _closeForm();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تعذّر حفظ التعديل، حاول مرة أخرى')),
      );
    }
  }

  void _startEdit(StudentNoteModel note) {
    setState(() {
      _editingNote = note;
      _noteController.text = note.note;
      _showForm = true;
    });
  }

  /// Leaves edit mode too, so the next "إضافة ملاحظة" starts blank rather
  /// than on the note that was being rewritten.
  void _closeForm() {
    setState(() {
      _showForm = false;
      if (_editingNote != null) {
        _editingNote = null;
        _noteController.clear();
      }
    });
  }

  Future<void> _deleteNote(int noteId) async {
    // A note deleted while open in the form has nothing left to save into.
    if (_editingNote?.id == noteId) _closeForm();
    try {
      await _repo.deleteNote(noteId);
      setState(() => _allNotes.removeWhere((n) => n.id == noteId));
    } catch (_) {}
  }

  Future<void> _pickStudents() async {
    String query = '';
    // Edited in the sheet; only applied when the teacher confirms.
    final picked = {..._selectedIds};
    final selected = await showModalBottomSheet<Set<int>>(
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
                  (s) => s.fullName.toLowerCase().contains(query.toLowerCase()),
                )
                .toList();
            final allPicked =
                _students.isNotEmpty && picked.length == _students.length;
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
                    AppText(
                      'اختر الطلاب',
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
                    if (query.isEmpty && _students.isNotEmpty) ...[
                      CheckboxListTile(
                        controlAffinity: ListTileControlAffinity.trailing,
                        activeColor: AppColors.primary,
                        tristate: true,
                        value: allPicked
                            ? true
                            : (picked.isEmpty ? false : null),
                        title: AppText(
                          'جميع الطلاب (${_students.length})',
                          style: AppTextStyles.labelMdBold.copyWith(
                            color: AppColors.primary,
                          ),
                          textAlign: TextAlign.end,
                        ),
                        onChanged: (_) => setSheetState(() {
                          if (allPicked) {
                            picked.clear();
                          } else {
                            picked.addAll(_students.map((s) => s.id));
                          }
                        }),
                      ),
                      Divider(height: 1, color: AppColors.outlineVariant),
                    ],
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 320.h),
                      child: filtered.isEmpty
                          ? Padding(
                              padding: EdgeInsets.symmetric(vertical: 24.h),
                              child: AppText(
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
                                return CheckboxListTile(
                                  controlAffinity:
                                      ListTileControlAffinity.trailing,
                                  activeColor: AppColors.primary,
                                  value: picked.contains(s.id),
                                  title: AppText(
                                    s.fullName,
                                    style: AppTextStyles.bodyMd,
                                    textAlign: TextAlign.end,
                                  ),
                                  onChanged: (checked) => setSheetState(() {
                                    if (checked ?? false) {
                                      picked.add(s.id);
                                    } else {
                                      picked.remove(s.id);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),
                    SizedBox(height: 12.h),
                    AppButton(
                      label: picked.isEmpty
                          ? 'اختر طالبًا واحدًا على الأقل'
                          : 'تأكيد (${picked.length})',
                      variant: AppButtonVariant.primary,
                      height: 44.h,
                      onPressed: picked.isEmpty
                          ? null
                          : () => Navigator.pop(ctx, {...picked}),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (selected == null) return;
    setState(() => _selectedIds = selected);
  }

  String? get _recipientLabel {
    if (_selectedIds.isEmpty) return null;
    if (_selectedIds.length == 1) {
      final id = _selectedIds.single;
      return _students.where((s) => s.id == id).firstOrNull?.fullName;
    }
    if (_selectedIds.length == _students.length) {
      return 'جميع الطلاب (${_students.length})';
    }
    return studentCountLabel(_selectedIds.length);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.user?.teacherId != null && _roster.isEmpty && !_isLoading) {
        _loadData();
      }
    });
    ref.listen(selectedHalaqaProvider, (previous, next) {
      if (next.selected?.id == previous?.selected?.id) return;
      // A recipient picked in the halaqa just left is not in this one; the
      // text typed so far is kept.
      setState(() => _selectedIds = {});
    });
    ref.watch(selectedHalaqaProvider.select((s) => s.selected?.id));

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
                          SizedBox(
                            height: 44.h,
                            child: AppButton(
                              label: 'إضافة ملاحظة',
                              variant: AppButtonVariant.gradient,
                              icon: Icons.add,
                              height: 44.h,
                              // While an edit is open this swaps it for a
                              // blank note instead of closing the form.
                              onPressed: () => _editingNote != null
                                  ? setState(() {
                                      _editingNote = null;
                                      _noteController.clear();
                                    })
                                  : setState(() => _showForm = !_showForm),
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
                            AppText(
                              _editingNote != null
                                  ? 'تعديل الملاحظة'
                                  : 'ملاحظة جديدة',
                              style: AppTextStyles.headlineSm.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            if (_editingNote != null)
                              _LockedRecipients(note: _editingNote!)
                            else
                              GestureDetector(
                                onTap: _pickStudents,
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
                                        child: AppText(
                                          _recipientLabel ?? 'اختر الطلاب...',
                                          style: AppTextStyles.labelMd.copyWith(
                                            color: _recipientLabel != null
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
                                    onPressed: _closeForm,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: AppButton(
                                    label: _editingNote != null
                                        ? 'حفظ التعديل'
                                        : 'حفظ',
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
                                child: AppText(
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
                                onEdit: () => _startEdit(_notes[i]),
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
  const _NoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });
  final StudentNoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final title = note.isBulk
        ? studentCountLabel(note.recipientIds.length)
        : note.studentName ?? '';
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
                AppText(
                  displayDate,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                AppText(
                  title,
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
                    child: note.isBulk
                        ? Icon(
                            Icons.group,
                            size: 18.w,
                            color: AppColors.onPrimaryContainer,
                          )
                        : AppText(
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
                ExpandableText(
                  note.note,
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurface,
                    height: 1.7,
                  ),
                  maxLines: kNoteFoldedLines,
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
                          message: note.isBulk
                              ? 'ستُحذف هذه الملاحظة من جميع الطلاب (${note.recipientIds.length}). لا يمكن التراجع عن هذا الإجراء.'
                              : 'هل أنت متأكد من حذف هذه الملاحظة؟ لا يمكن التراجع عن هذا الإجراء.',
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
                          AppText(
                            'حذف',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 16.w),
                    GestureDetector(
                      onTap: onEdit,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.edit_outlined,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          SizedBox(width: 4.w),
                          AppText(
                            'تعديل',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.primary,
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

/// Who a note being edited went to. Shown where the picker sits for a new
/// note, but fixed: an edit changes the text, not the students.
class _LockedRecipients extends StatelessWidget {
  const _LockedRecipients({required this.note});
  final StudentNoteModel note;

  @override
  Widget build(BuildContext context) {
    final label = note.isBulk
        ? studentCountLabel(note.recipientIds.length)
        : note.studentName ?? '';
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.inputBorder),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      child: Row(
        children: [
          Icon(
            Icons.lock_outline,
            size: 18.w,
            color: AppColors.onSurfaceVariant,
          ),
          Expanded(
            child: AppText(
              label,
              style: AppTextStyles.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

/// "طالبان", "3 طلاب", "11 طالبًا": the recipients of a note sent to several.
@visibleForTesting
String studentCountLabel(int count) {
  if (count == 2) return 'طالبان';
  final mod100 = count % 100;
  if (mod100 >= 3 && mod100 <= 10) return '$count طلاب';
  return '$count طالبًا';
}
