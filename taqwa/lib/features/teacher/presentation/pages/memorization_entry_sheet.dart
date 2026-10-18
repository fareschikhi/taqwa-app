import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/segmented_selector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_subject.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/utils/memorization_error_message.dart';
import '../../../../core/utils/memorization_history.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/teacher_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class MemorizationEntrySheet extends StatefulWidget {
  const MemorizationEntrySheet({super.key, required this.student});
  final TeacherStudentModel student;

  @override
  State<MemorizationEntrySheet> createState() => _MemorizationEntrySheetState();
}

class _MemorizationEntrySheetState extends State<MemorizationEntrySheet> {
  MemorizationSubject _selectedSubject = MemorizationSubject.quran;
  int? _selectedSurah;
  String? _selectedHadithBook;
  bool _hadithPrefillLoaded = false;
  int _amount = 1;
  MemorizationType? _selectedType;
  bool _isSaving = false;

  final _repo = TeacherRepository();
  final _studentRepo = StudentRepository();

  bool get _isHadith => _selectedSubject == MemorizationSubject.hadith;

  /// Hadith has no page/hizb concept, so it always counts in hadiths
  /// regardless of type; Quran keeps following the selected type's unit.
  String get _amountLabel =>
      _isHadith ? 'عدد الأحاديث' : (_selectedType?.amountLabel ?? 'العدد');
  int get _maxAmount => _isHadith ? 50 : (_selectedType?.maxAmount ?? 1);

  void _onSubjectChanged(MemorizationSubject subject) {
    setState(() {
      _selectedSubject = subject;
      // Pages/hizbs and hadiths are not interchangeable quantities; carrying
      // the old number across a subject switch would silently change what it
      // means, same reasoning as the existing type switch below.
      _amount = 1;
    });
    if (subject == MemorizationSubject.hadith && !_hadithPrefillLoaded) {
      _loadHadithPrefill();
    }
  }

  /// Preselects the book of the student's most recent hadith entry, so
  /// continuing the same book is a no-op. A reference that is not one of the
  /// student's assigned books (an older free-text entry, or a book the admin
  /// has since unticked) leaves the dropdown empty. Best-effort: a failed
  /// fetch is the same as a student with no prior hadith entries.
  ///
  /// A student assigned a single book needs no choosing at all, so that one
  /// is selected straight away.
  Future<void> _loadHadithPrefill() async {
    _hadithPrefillLoaded = true;
    final books = widget.student.hadithBooks;
    if (books.length == 1) {
      setState(() => _selectedHadithBook = books.single);
      return;
    }
    try {
      final history = await _studentRepo.getMemorizationHistory(
        widget.student.id,
      );
      final hadithRecords = history
          .where((r) => r['subject'] == 'HADITH')
          .toList();
      final latest = recentMemorization(hadithRecords, limit: 1);
      if (!mounted || latest.isEmpty) return;
      final reference = latest.first['hadithReference'] as String?;
      if (books.contains(reference) && _selectedHadithBook == null) {
        setState(() => _selectedHadithBook = reference);
      }
    } catch (_) {
      // Prefill is a convenience, not a requirement — the teacher can still
      // pick the book by hand.
    }
  }

  /// The unit only becomes known once a type is picked, so the counter stays
  /// inert until then rather than collecting a number with no unit attached.
  void _onTypeChanged(MemorizationType? type) {
    setState(() {
      _selectedType = type;
      _amount = 1;
    });
  }

  Future<void> _submit() async {
    final missingIdentity = _isHadith
        ? _selectedHadithBook == null
        : _selectedSurah == null;

    if (missingIdentity || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isHadith
                ? 'يرجى تحديد الكتاب ونوع المراجعة'
                : 'يرجى تحديد السورة ونوع المراجعة',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final created = await _repo.submitMemorization(
        studentId: widget.student.id,
        surahNumber: _isHadith ? null : _selectedSurah,
        hadithReference: _isHadith ? _selectedHadithBook : null,
        amountDone: _amount,
        memorizationType: _selectedType!.apiValue,
        subject: _selectedSubject.apiValue,
      );
      if (mounted) Navigator.pop(context, created);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: AppText(
              _errorMessage(e),
              style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _errorMessage(Object error) => memorizationErrorMessage(error);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom, // keyboard-safe
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusLg),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
        // Scrollable so an open keyboard (which shrinks the available height
        // via the viewInsets padding above) makes the content scroll instead
        // of overflowing and clipping the تسجيل button underneath it.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusFull,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              AppText(
                widget.student.fullName,
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 12.h),

              AppCard(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (widget.student.tracksHadith) ...[
                      AppText(
                        'النوع',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SegmentedSelector<MemorizationSubject>(
                        options: const [
                          SegmentOption(
                            value: MemorizationSubject.quran,
                            label: 'القرآن',
                          ),
                          SegmentOption(
                            value: MemorizationSubject.hadith,
                            label: 'الحديث',
                          ),
                        ],
                        selected: _selectedSubject,
                        onChanged: _onSubjectChanged,
                      ),
                      SizedBox(height: 12.h),
                    ],

                    if (_isHadith) ...[
                      AppText(
                        'الكتاب',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedHadithBook,
                            isExpanded: true,
                            hint: AppText(
                              'اختر الكتاب...',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.inputPlaceholder,
                              ),
                            ),
                            // Only the books the admin assigned this student;
                            // the server refuses any other.
                            items: widget.student.hadithBooks
                                .map(
                                  (b) => DropdownMenuItem(
                                    value: b,
                                    child: AppText(b),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedHadithBook = v),
                          ),
                        ),
                      ),
                    ] else ...[
                      AppText(
                        'السورة',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          border: Border.all(color: AppColors.inputBorder),
                        ),
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedSurah,
                            isExpanded: true,
                            hint: AppText(
                              'اختر السورة...',
                              style: AppTextStyles.labelMd.copyWith(
                                color: AppColors.inputPlaceholder,
                              ),
                            ),
                            items: kSurahs
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: s.number,
                                    child: AppText(s.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedSurah = v),
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),

                    AppText(
                      'نوع العرض',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    SegmentedSelector<MemorizationType>(
                      options: const [
                        SegmentOption(
                          value: MemorizationType.majorReview,
                          label: 'مراجعة كبرى',
                        ),
                        SegmentOption(
                          value: MemorizationType.minorReview,
                          label: 'مراجعة صغرى',
                        ),
                        SegmentOption(
                          value: MemorizationType.hifz,
                          label: 'حفظ',
                        ),
                      ],
                      selected: _selectedType,
                      onChanged: _onTypeChanged,
                    ),
                    SizedBox(height: 12.h),

                    AppText(
                      // Revision is counted in hizbs, new Quran memorization in
                      // pages, any hadith entry in hadiths.
                      _selectedType == null ? 'العدد' : _amountLabel,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusMd,
                        ),
                        border: Border.all(color: AppColors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            onPressed: _selectedType == null
                                ? null
                                : () => setState(() {
                                    if (_amount < _maxAmount) {
                                      _amount++;
                                    }
                                  }),
                            color: AppColors.primary,
                          ),
                          Expanded(
                            child: AppText(
                              _selectedType == null ? '—' : '$_amount',
                              textAlign: TextAlign.center,
                              style: AppTextStyles.bodyMdBold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            onPressed: _selectedType == null
                                ? null
                                : () => setState(() {
                                    if (_amount > 1) _amount--;
                                  }),
                            color: AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 16.h),
              AppButton(
                label: 'تسجيل',
                variant: AppButtonVariant.gradient,
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
