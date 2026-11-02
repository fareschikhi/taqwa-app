import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/note_timeline.dart';
import '../../../data/models/student_note_model.dart';
import '../../../data/repositories/student_repository.dart';

/// The whole timeline of a child's teacher notes. The dashboard shows only the
/// latest few; this is where "عرض الكل" leads.
class ChildNotesPage extends StatefulWidget {
  const ChildNotesPage({
    super.key,
    required this.studentId,
    required this.childName,
  });

  final int studentId;

  /// In the title, so a parent of several children can see whose notes
  /// these are.
  final String childName;

  @override
  State<ChildNotesPage> createState() => _ChildNotesPageState();
}

class _ChildNotesPageState extends State<ChildNotesPage> {
  final _repo = StudentRepository();

  List<StudentNoteModel> _notes = [];
  bool _isLoading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final notes = await _repo.getNotes(widget.studentId);
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceContainerLowest,
        title: AppText(
          widget.childName.isEmpty
              ? 'ملاحظات المعلم'
              : 'ملاحظات ${widget.childName}',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        centerTitle: true,
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // A single line in a scrollable list, so pulling down retries a failed
    // load and refreshes an empty one.
    Widget message(String text, Color color) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: 120.h),
        AppText(
          text,
          style: AppTextStyles.bodyMd.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: _failed
          ? message(
              'تعذر تحميل الملاحظات، اسحب للأسفل لإعادة المحاولة',
              AppColors.error,
            )
          : _notes.isEmpty
          ? message('لا توجد ملاحظات بعد', AppColors.onSurfaceVariant)
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 32.h),
              children: [NoteTimeline(notes: _notes)],
            ),
    );
  }
}
