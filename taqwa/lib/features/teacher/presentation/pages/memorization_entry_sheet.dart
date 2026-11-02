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
import '../../../../core/utils/memorization_amount.dart';
import '../../../../core/utils/memorization_duplicates.dart';
import '../../../../core/utils/memorization_history.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/teacher_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// How the teacher counts a Quran entry. The stored amount is always pages;
/// the unit only sets where the counter starts and how far + and − move it.
enum _AmountUnit { pages, hizb, surah }

/// What a saved entry hands back: the row the server created, and whether
/// the teacher asked to go straight on to the next student.
typedef MemorizationEntryResult = ({Map<String, dynamic> record, bool next});

class MemorizationEntrySheet extends StatefulWidget {
  const MemorizationEntrySheet({
    super.key,
    required this.student,
    this.nextStudentName,
  });
  final TeacherStudentModel student;

  /// Who would be recorded after this student, or null outside the
  /// attendance sheet's run through the halaqa. When set, the sheet offers
  /// to save and move on, so a whole halaqa never goes back to the list.
  final String? nextStudentName;

  @override
  State<MemorizationEntrySheet> createState() => _MemorizationEntrySheetState();
}

class _MemorizationEntrySheetState extends State<MemorizationEntrySheet> {
  MemorizationSubject _selectedSubject = MemorizationSubject.quran;
  int? _selectedSurah;
  String? _selectedHadithBook;
  bool _hadithPrefillLoaded = false;
  double _amount = 1;
  _AmountUnit _unit = _AmountUnit.pages;
  MemorizationType? _selectedType;
  bool _isSaving = false;

  /// The student's history, fetched once and shared by the Quran and the
  /// hadith prefill. A failed fetch reads as no history at all.
  Future<List<Map<String, dynamic>>>? _history;

  /// The Quran entry the form was filled from, shown above it so the teacher
  /// knows the choices are last session's and not a default.
  Map<String, dynamic>? _prefilledFrom;

  /// The middle of the counter is typed into directly, so a teacher recording
  /// ten pages is not made to tap + nine times.
  final _amountController = TextEditingController(text: '1');
  final _amountFocus = FocusNode();

  final _repo = TeacherRepository();
  final _studentRepo = StudentRepository();

  bool get _isHadith => _selectedSubject == MemorizationSubject.hadith;

  /// Hadith has no page concept, so it always counts in hadiths; every Quran
  /// entry, whatever its type, counts in pages.
  String get _amountLabel => _isHadith ? 'عدد الأحاديث' : kPageAmountLabel;
  int get _maxAmount => _isHadith ? 50 : kMushafPages;

  /// Quran is recited by the half page; a hadith is always whole. The server
  /// enforces the same rule.
  bool get _allowsHalf => !_isHadith;
  double get _minAmount => _allowsHalf ? 0.5 : 1;

  /// A hizb moves the counter ten pages at a time; pages and a whole surah
  /// both adjust by a single page.
  int get _step => !_isHadith && _unit == _AmountUnit.hizb ? kPagesPerHizb : 1;

  int? get _selectedSurahPages {
    for (final surah in kSurahs) {
      if (surah.number == _selectedSurah) return surah.pageCount;
    }
    return null;
  }

  /// Where the counter starts for [unit]: one page, one hizb, or the whole of
  /// the selected surah (one page until a surah is picked).
  double _startAmountFor(_AmountUnit unit) => switch (unit) {
    _AmountUnit.pages => 1,
    _AmountUnit.hizb => kPagesPerHizb.toDouble(),
    _AmountUnit.surah => (_selectedSurahPages ?? 1).toDouble(),
  };

  @override
  void initState() {
    super.initState();
    // Leaving the field settles whatever was typed into the stored amount,
    // so an empty or out-of-range entry never stays on screen.
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) _commitTypedAmount();
    });
    _loadQuranPrefill();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() => _history ??= _studentRepo
      .getMemorizationHistory(widget.student.id)
      .catchError((_) => <Map<String, dynamic>>[]);

  /// Most sessions carry on from the last one, so the form opens on the
  /// student's latest Quran entry — same surah, type and pages — and the
  /// common case is a single tap on تسجيل. Anything the teacher has already
  /// touched by the time the history arrives is left as they set it.
  Future<void> _loadQuranPrefill() async {
    final history = await _loadHistory();
    final quran = history.where((r) => r['subject'] != 'HADITH').toList();
    final latest = recentMemorization(quran, limit: 1);
    if (!mounted || latest.isEmpty || _isHadith) return;
    final record = latest.first;

    final surah = (record['surahNumber'] as num?)?.toInt();
    final type = MemorizationTypeX.fromApi(
      record['memorizationType'] as String?,
    );
    final amount = (record['amountDone'] as num?)?.toDouble();
    final untouchedAmount =
        _amount == 1 && _unit == _AmountUnit.pages && !_amountFocus.hasFocus;

    setState(() {
      if (_selectedSurah == null && kSurahs.any((s) => s.number == surah)) {
        _selectedSurah = surah;
      }
      _selectedType ??= type;
      _prefilledFrom = record;
    });
    if (untouchedAmount && amount != null && amount >= _minAmount) {
      _setAmount(amount);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  /// Sets the amount and shows it, clamped to what the current unit allows.
  void _setAmount(double value) {
    final clamped = value.clamp(_minAmount, _maxAmount.toDouble()).toDouble();
    setState(() => _amount = clamped);
    _amountController.text = formatAmount(clamped);
  }

  /// A valid typed value becomes the amount right away, so tapping تسجيل with
  /// the keyboard still open saves what is on screen.
  void _onAmountTyped(String text) {
    final value = parseAmount(text, allowHalf: _allowsHalf);
    if (value == null || value < _minAmount) return;
    setState(
      () => _amount = value > _maxAmount ? _maxAmount.toDouble() : value,
    );
  }

  /// An empty or zero entry falls back to the last good amount; anything
  /// above the unit's ceiling is brought down to it.
  void _commitTypedAmount() {
    final value = parseAmount(_amountController.text, allowHalf: _allowsHalf);
    _setAmount(value == null || value < _minAmount ? _amount : value);
  }

  void _onSubjectChanged(MemorizationSubject subject) {
    setState(() {
      _selectedSubject = subject;
      // Pages and hadiths are not interchangeable quantities; carrying the
      // old number across a subject switch would silently change what it
      // means.
      _unit = _AmountUnit.pages;
      _amount = 1;
    });
    _amountController.text = '1';
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
      final history = await _loadHistory();
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

  void _onUnitChanged(_AmountUnit unit) {
    setState(() => _unit = unit);
    _setAmount(_startAmountFor(unit));
  }

  /// While counting by surah, picking another surah means reciting that one,
  /// so the counter follows it to its page count.
  void _onSurahChanged(int? number) {
    setState(() => _selectedSurah = number);
    if (_unit == _AmountUnit.surah) _setAmount(_startAmountFor(_unit));
  }

  Future<void> _submit({bool next = false}) async {
    // Settles a half-typed amount ("3.") before it is sent.
    if (_amountFocus.hasFocus) _amountFocus.unfocus();
    _commitTypedAmount();

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
      if (mounted) {
        Navigator.pop<MemorizationEntryResult>(context, (
          record: created,
          next: next,
        ));
      }
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
              if (_prefilledFrom != null && !_isHadith) ...[
                SizedBox(height: 4.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: AppText(
                        'آخر تسجيل: ${memorizationSummary(_prefilledFrom!)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Icon(
                      Icons.history_rounded,
                      size: 16.w,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ],
                ),
              ],
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
                            onChanged: _onSurahChanged,
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
                          label: 'مراجعة وضبط',
                        ),
                        SegmentOption(
                          value: MemorizationType.minorReview,
                          label: 'جمع',
                        ),
                        SegmentOption(
                          value: MemorizationType.hifz,
                          label: 'حفظ',
                        ),
                      ],
                      selected: _selectedType,
                      onChanged: (type) => setState(() => _selectedType = type),
                    ),
                    SizedBox(height: 12.h),

                    if (!_isHadith) ...[
                      AppText(
                        'طريقة العد',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SegmentedSelector<_AmountUnit>(
                        options: const [
                          SegmentOption(
                            value: _AmountUnit.surah,
                            label: 'سورة',
                          ),
                          SegmentOption(value: _AmountUnit.hizb, label: 'حزب'),
                          SegmentOption(
                            value: _AmountUnit.pages,
                            label: 'صفحات',
                          ),
                        ],
                        selected: _unit,
                        onChanged: _onUnitChanged,
                      ),
                      SizedBox(height: 12.h),
                    ],

                    AppText(
                      _amountLabel,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    ListenableBuilder(
                      listenable: _amountFocus,
                      builder: (context, child) => AnimatedContainer(
                        duration: AppConstants.animFast,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                          border: Border.all(
                            color: _amountFocus.hasFocus
                                ? AppColors.inputFocusBorder
                                : AppColors.inputBorder,
                          ),
                        ),
                        child: child,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 18),
                            tooltip: 'زيادة',
                            onPressed: _amount >= _maxAmount
                                ? null
                                : () => _setAmount(_amount + _step),
                            color: AppColors.primary,
                          ),
                          Expanded(
                            child: Semantics(
                              label: _amountLabel,
                              child: TextField(
                                // Re-keyed per unit so the formatter
                                // never holds on to the previous
                                // unit's half-page rule.
                                key: ValueKey(_allowsHalf),
                                controller: _amountController,
                                focusNode: _amountFocus,
                                textAlign: TextAlign.center,
                                textDirection: TextDirection.ltr,
                                // `signed: true` is the workaround for
                                // Samsung's keyboard, which hides the
                                // decimal key for decimal-only number
                                // fields. The formatter still refuses '-'.
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: _allowsHalf,
                                  signed: _allowsHalf,
                                ),
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  MemorizationAmountInputFormatter(
                                    allowHalf: _allowsHalf,
                                  ),
                                ],
                                // Select-all on tap: typing "10"
                                // replaces the 1 rather than making 110.
                                onTap: () =>
                                    _amountController.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset:
                                          _amountController.text.length,
                                    ),
                                onChanged: _onAmountTyped,
                                onSubmitted: (_) => _commitTypedAmount(),
                                style: AppTextStyles.bodyMdBold.copyWith(
                                  color: AppColors.onSurface,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  filled: false,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 18),
                            tooltip: 'إنقاص',
                            onPressed: _amount <= _minAmount
                                ? null
                                : () => _setAmount(_amount - _step),
                            color: AppColors.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                    if (_allowsHalf) ...[
                      SizedBox(height: 6.h),
                      AppText(
                        'اضغط على الرقم لكتابته، ويمكن إدخال نصف صفحة (مثل 1.5)',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(height: 16.h),
              // In a run through the halaqa, moving on is the usual next step,
              // so it takes the main button and stopping takes the quiet one.
              // The name sits on its own line: a button label does not shrink,
              // and a long name inside one would overflow it.
              if (widget.nextStudentName != null) ...[
                AppText(
                  'التالي: ${widget.nextStudentName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 6.h),
                AppButton(
                  label: 'تسجيل والتالي',
                  variant: AppButtonVariant.gradient,
                  icon: Icons.skip_next_rounded,
                  isLoading: _isSaving,
                  onPressed: () => _submit(next: true),
                ),
                SizedBox(height: 8.h),
                AppButton(
                  label: 'تسجيل والعودة',
                  variant: AppButtonVariant.secondary,
                  icon: Icons.save_outlined,
                  onPressed: _isSaving ? null : _submit,
                ),
              ] else
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
