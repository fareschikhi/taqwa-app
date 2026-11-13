import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/features/teacher/presentation/pages/segmented_selector.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_subject.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/utils/ayah_range.dart';
import '../../../../core/utils/memorization_error_message.dart';
import '../../../../core/utils/memorization_amount.dart';
import '../../../../core/utils/memorization_duplicates.dart';
import '../../../../core/utils/memorization_history.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/user_selector_field.dart';
import '../../../data/models/teacher_student_model.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/repositories/teacher_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// How the teacher counts a Quran entry. Pages, hizb and surah are all stored
/// as pages — those units only set where the counter starts and how far + and
/// − move it. Ayahs are stored as an ayah range with its own total, never
/// turned into pages.
enum _AmountUnit { pages, hizb, surah, ayahs }

/// How the teacher counts a hadith entry. Unlike [_AmountUnit] this is stored
/// with the entry: 2 pages and 2 hadiths are different amounts.
enum _HadithUnit { hadiths, pages }

/// The surah dropdown's first choice: the entry records only its amount.
const String _kNoSurahChoice = 'بدون تحديد السورة';

/// The dropdown value standing for [_kNoSurahChoice]. Not null: a menu that
/// returns null reads to [DropdownButton] as dismissed, so picking "no surah"
/// after a surah would never fire. 0 is outside the mushaf's 1–114.
const int _kNoSurah = 0;

/// What a saved entry hands back: the row the server created, and whether
/// the teacher asked to go straight on to the next student.
typedef MemorizationEntryResult = ({Map<String, dynamic> record, bool next});

class MemorizationEntrySheet extends StatefulWidget {
  const MemorizationEntrySheet({
    super.key,
    required TeacherStudentModel this.student,
    this.nextStudentName,
  }) : students = null;

  /// For a student who recited outside the halaqa session: the teacher picks
  /// him from [students] in the sheet, and the entry earns its points without
  /// touching attendance — the server skips the absence check and the day's
  /// missed-recitation charge.
  const MemorizationEntrySheet.outsideSession({
    super.key,
    required List<TeacherStudentModel> this.students,
  }) : student = null,
       nextStudentName = null;

  /// The student being recorded, fixed by the caller. Null when the teacher
  /// picks one from [students] instead.
  final TeacherStudentModel? student;

  /// Who the teacher can pick from, set only for an entry outside the session.
  final List<TeacherStudentModel>? students;

  /// Who would be recorded after this student, or null outside the
  /// attendance sheet's run through the halaqa. When set, the sheet offers
  /// to save and move on, so a whole halaqa never goes back to the list.
  final String? nextStudentName;

  @override
  State<MemorizationEntrySheet> createState() => _MemorizationEntrySheetState();
}

class _MemorizationEntrySheetState extends State<MemorizationEntrySheet> {
  /// Who this entry is for: the caller's student, or the one the teacher
  /// picked. Null until a pick in [MemorizationEntrySheet.outsideSession].
  TeacherStudentModel? _student;

  bool get _outsideSession => widget.students != null;

  MemorizationSubject _selectedSubject = MemorizationSubject.quran;
  int? _selectedSurah;
  String? _selectedHadithBook;
  bool _hadithPrefillLoaded = false;
  double _amount = 1;
  _AmountUnit _unit = _AmountUnit.pages;
  _HadithUnit _hadithUnit = _HadithUnit.hadiths;

  /// Set once the teacher picks a hadith unit, so the history prefill never
  /// overrides their choice.
  bool _hadithUnitTouched = false;
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

  /// The two ends of an ayah range, typed by the teacher. Kept as text so a
  /// half-typed number is never rewritten under their finger.
  final _ayahFromController = TextEditingController(text: '1');
  final _ayahToController = TextEditingController(text: '1');

  /// Shown under the range once the teacher tries to save it, and cleared as
  /// soon as they type again.
  String? _ayahError;

  final _repo = TeacherRepository();
  final _studentRepo = StudentRepository();

  bool get _isHadith => _selectedSubject == MemorizationSubject.hadith;

  /// A Quran entry counts in pages unless it counts ayahs; a hadith entry
  /// counts in single hadiths unless the teacher switched it to pages.
  bool get _countsPages =>
      _isHadith ? _hadithUnit == _HadithUnit.pages : !_countsAyahs;

  /// A Quran entry counted in ayahs rather than pages.
  bool get _countsAyahs => !_isHadith && _unit == _AmountUnit.ayahs;

  /// Ayahs inside a chosen surah are typed as «من آية / إلى آية». With no
  /// surah there is nothing to number them against, so the counter records
  /// only how many.
  bool get _countsAyahRange => _countsAyahs && _selectedSurah != null;

  int? get _ayahFrom =>
      parseAmount(_ayahFromController.text, allowHalf: false)?.toInt();
  int? get _ayahTo =>
      parseAmount(_ayahToController.text, allowHalf: false)?.toInt();

  /// The typed range when it is usable in the selected surah, else null.
  ({int from, int to})? get _validAyahRange {
    final surah = surahOf(_selectedSurah);
    final from = _ayahFrom;
    final to = _ayahTo;
    if (surah == null || from == null || to == null) return null;
    final error = ayahRangeError(
      from: from,
      to: to,
      ayahCount: surah.ayahCount,
    );
    return error == null ? (from: from, to: to) : null;
  }

  void _setAyahRange(int from, int to) {
    _ayahFromController.text = '$from';
    _ayahToController.text = '$to';
    _ayahError = null;
  }

  String get _amountLabel => _countsAyahs
      ? 'عدد الآيات'
      : _countsPages
      ? kPageAmountLabel
      : 'عدد الأحاديث';
  int get _maxAmount => _countsAyahs
      ? kMaxAyahsPerEntry
      : _countsPages
      ? kMushafPages
      : 50;

  /// Pages are recited by the half; a single hadith is always whole. The
  /// server enforces the same rule.
  bool get _allowsHalf => _countsPages;
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
    // The range, not the counter, holds an ayah entry's amount.
    _AmountUnit.ayahs => 1,
  };

  @override
  void initState() {
    super.initState();
    // Leaving the field settles whatever was typed into the stored amount,
    // so an empty or out-of-range entry never stays on screen.
    _amountFocus.addListener(() {
      if (!_amountFocus.hasFocus) _commitTypedAmount();
    });
    _student = widget.student;
    if (_student != null) _loadQuranPrefill();
  }

  Future<List<Map<String, dynamic>>> _loadHistory() => _history ??= _studentRepo
      .getMemorizationHistory(_student!.id)
      .catchError((_) => <Map<String, dynamic>>[]);

  /// Another student means another history, so the form starts over and is
  /// prefilled from his last session instead of keeping the previous pick's.
  void _onStudentPicked(UserOption option) {
    if (option.id == _student?.id) return;
    final picked = widget.students!.firstWhere((s) => s.id == option.id);
    setState(() {
      _student = picked;
      _history = null;
      _prefilledFrom = null;
      _hadithPrefillLoaded = false;
      _selectedSubject = MemorizationSubject.quran;
      _selectedSurah = null;
      _selectedHadithBook = null;
      _selectedType = null;
      _unit = _AmountUnit.pages;
      _hadithUnit = _HadithUnit.hadiths;
      _hadithUnitTouched = false;
      _amount = 1;
      _setAyahRange(1, 1);
    });
    _amountController.text = '1';
    _loadQuranPrefill();
  }

  /// Most sessions carry on from the last one, so the form opens on the
  /// student's latest Quran entry — same surah, type and pages — and the
  /// common case is a single tap on تسجيل. Anything the teacher has already
  /// touched by the time the history arrives is left as they set it.
  Future<void> _loadQuranPrefill() async {
    final student = _student;
    final history = await _loadHistory();
    final quran = history.where((r) => r['subject'] != 'HADITH').toList();
    final latest = recentMemorization(quran, limit: 1);
    // A history that arrives after the teacher picked someone else belongs
    // to the previous student.
    if (!mounted || student != _student || latest.isEmpty || _isHadith) {
      return;
    }
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

    // A student recorded by ayahs carries on from the ayah after last time,
    // in the same surah, so the teacher only confirms.
    final lastFrom = (record['ayahFrom'] as num?)?.toInt();
    final lastTo = (record['ayahTo'] as num?)?.toInt();
    final lastSurah = surahOf(surah);
    if (record['unit'] == 'AYAH' &&
        untouchedAmount &&
        _selectedSurah == surah &&
        lastSurah != null &&
        lastFrom != null &&
        lastTo != null) {
      final next = nextAyahRange(
        lastFrom: lastFrom,
        lastTo: lastTo,
        ayahCount: lastSurah.ayahCount,
      );
      setState(() {
        _unit = _AmountUnit.ayahs;
        _setAyahRange(next.from, next.to);
      });
      return;
    }
    // Ayahs counted without a surah carry on as a count of ayahs.
    if (record['unit'] == 'AYAH' &&
        surah == null &&
        untouchedAmount &&
        _selectedSurah == null &&
        amount != null) {
      setState(() => _unit = _AmountUnit.ayahs);
      _setAmount(amount);
      return;
    }
    // An ayah count is not a page count, so it never seeds the page counter.
    if (record['unit'] != 'AYAH' &&
        untouchedAmount &&
        amount != null &&
        amount >= _minAmount) {
      _setAmount(amount);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _amountFocus.dispose();
    _ayahFromController.dispose();
    _ayahToController.dispose();
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
  ///
  /// The unit follows the last hadith entry too: a teacher who counts a book
  /// in pages keeps counting it in pages.
  Future<void> _loadHadithPrefill() async {
    _hadithPrefillLoaded = true;
    final student = _student!;
    final books = student.hadithBooks;
    if (books.length == 1) {
      setState(() => _selectedHadithBook = books.single);
    }
    try {
      final history = await _loadHistory();
      final hadithRecords = history
          .where((r) => r['subject'] == 'HADITH')
          .toList();
      final latest = recentMemorization(hadithRecords, limit: 1);
      if (!mounted || student != _student || latest.isEmpty || !_isHadith) {
        return;
      }
      final reference = latest.first['hadithReference'] as String?;
      if (books.contains(reference) && _selectedHadithBook == null) {
        setState(() => _selectedHadithBook = reference);
      }
      if (!_hadithUnitTouched && latest.first['unit'] == 'PAGE') {
        _onHadithUnitChanged(_HadithUnit.pages, byTeacher: false);
      }
    } catch (_) {
      // Prefill is a convenience, not a requirement — the teacher can still
      // pick the book by hand.
    }
  }

  void _onUnitChanged(_AmountUnit unit) {
    setState(() {
      _unit = unit;
      _ayahError = null;
    });
    _setAmount(_startAmountFor(unit));
  }

  /// Pages and hadiths are different quantities, so the count restarts at
  /// one rather than carrying "2.5" over into hadiths.
  void _onHadithUnitChanged(_HadithUnit unit, {bool byTeacher = true}) {
    setState(() {
      _hadithUnit = unit;
      if (byTeacher) _hadithUnitTouched = true;
    });
    _setAmount(1);
  }

  /// While counting by surah, picking another surah means reciting that one,
  /// so the counter follows it to its page count.
  ///
  /// An ayah range that no longer fits the new surah is pulled inside it, so
  /// «1–200» typed for آل عمران never stays on screen for الفاتحة.
  ///
  /// Clearing the surah while counting ayahs keeps how many were typed: the
  /// range «1–20» becomes a count of 20.
  void _onSurahChanged(int? number) {
    final carried = _countsAyahs && number == null ? _validAyahRange : null;
    setState(() {
      _selectedSurah = number;
      _ayahError = null;
      final ayahs = surahOf(number)?.ayahCount;
      if (ayahs == null) return;
      final from = _ayahFrom;
      final to = _ayahTo;
      if (from == null || from > ayahs) {
        _setAyahRange(1, 1);
      } else if (to == null || to > ayahs) {
        _setAyahRange(from, ayahs);
      }
    });
    if (_unit == _AmountUnit.surah) _setAmount(_startAmountFor(_unit));
    if (_countsAyahs && number == null) {
      _setAmount(
        carried != null
            ? ayahCountIn(carried.from, carried.to).toDouble()
            : _amount,
      );
    }
  }

  Future<void> _submit({bool next = false}) async {
    // Settles a half-typed amount ("3.") before it is sent.
    if (_amountFocus.hasFocus) _amountFocus.unfocus();
    _commitTypedAmount();

    // A hadith entry must name its book; a Quran entry may leave the surah
    // out and record only the amount.
    final missingIdentity = _isHadith && _selectedHadithBook == null;

    if (missingIdentity || _selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            _isHadith
                ? 'يرجى تحديد الكتاب ونوع المراجعة'
                : 'يرجى تحديد نوع العرض',
            style: AppTextStyles.labelMd.copyWith(color: AppColors.onPrimary),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // The range is checked here, not as it is typed: «2» on the way to «25»
    // is not a mistake worth flagging.
    final range = _countsAyahRange ? _validAyahRange : null;
    if (_countsAyahRange && range == null) {
      final error = ayahRangeError(
        from: _ayahFrom,
        to: _ayahTo,
        ayahCount: surahOf(_selectedSurah)!.ayahCount,
      );
      setState(() => _ayahError = error);
      return;
    }

    setState(() => _isSaving = true);
    try {
      final created = await _repo.submitMemorization(
        studentId: _student!.id,
        outsideSession: _outsideSession,
        surahNumber: _isHadith ? null : _selectedSurah,
        hadithReference: _isHadith ? _selectedHadithBook : null,
        amountDone: range != null ? ayahCountIn(range.from, range.to) : _amount,
        memorizationType: _selectedType!.apiValue,
        subject: _selectedSubject.apiValue,
        unit: _isHadith
            ? (_hadithUnit == _HadithUnit.pages ? 'PAGE' : 'HADITH')
            : (_countsAyahs ? 'AYAH' : null),
        ayahFrom: range?.from,
        ayahTo: range?.to,
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

  /// The title, what this entry does and does not do, and the searchable
  /// student field, for [MemorizationEntrySheet.outsideSession].
  List<Widget> _buildStudentPicker() => [
    AppText(
      'تسجيل حفظ خارج الحصة',
      style: AppTextStyles.headlineMd.copyWith(color: AppColors.onSurface),
    ),
    SizedBox(height: 4.h),
    Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(
          child: AppText(
            'تُضاف نقاط الحفظ فقط، ولا علاقة له بالحضور',
            textAlign: TextAlign.end,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(width: 6.w),
        Icon(
          Icons.info_outline_rounded,
          size: 16.w,
          color: AppColors.onSurfaceVariant,
        ),
      ],
    ),
    SizedBox(height: 12.h),
    UserSelectorField(
      label: 'الطالب',
      hint: 'اختر الطالب',
      searchHint: 'ابحث باسم الطالب',
      emptyText: 'لا يوجد طالب بهذا الاسم',
      options: [
        for (final s in widget.students!)
          UserOption(id: s.id, fullName: s.fullName, avatar: s.avatar),
      ],
      selectedId: _student?.id,
      enabled: !_isSaving,
      onSelected: _onStudentPicked,
    ),
  ];

  /// «من آية» and «إلى آية» side by side, right to left as they are read,
  /// with the count underneath so the teacher sees what will be saved.
  Widget _buildAyahRange() {
    final surah = surahOf(_selectedSurah);
    final range = _validAyahRange;
    final String helper;
    if (_ayahError != null) {
      helper = _ayahError!;
    } else if (surah == null) {
      helper = 'اختر السورة أولاً';
    } else if (range != null) {
      final count = ayahCountIn(range.from, range.to);
      helper =
          'المجموع: $count $kAyahUnitLabel · سورة ${surah.name} '
          '${surah.ayahCount} $kAyahUnitLabel';
    } else {
      helper = 'سورة ${surah.name} ${surah.ayahCount} $kAyahUnitLabel';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _AyahField(
                label: 'إلى آية',
                controller: _ayahToController,
                enabled: surah != null,
                hasError: _ayahError != null,
                onChanged: (_) => setState(() => _ayahError = null),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _AyahField(
                label: 'من آية',
                controller: _ayahFromController,
                enabled: surah != null,
                hasError: _ayahError != null,
                onChanged: (_) => setState(() => _ayahError = null),
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        Semantics(
          liveRegion: _ayahError != null,
          child: AppText(
            helper,
            textAlign: TextAlign.right,
            style: AppTextStyles.labelMd.copyWith(
              color: _ayahError != null
                  ? AppColors.error
                  : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

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
              if (_outsideSession)
                ..._buildStudentPicker()
              else
                AppText(
                  _student!.fullName,
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              // Nothing to fill in until the teacher has said who recited.
              if (_student != null) ...[
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
                      if (_student!.tracksHadith) ...[
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
                              items: _student!.hadithBooks
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
                          'السورة (اختياري)',
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
                              value: _selectedSurah ?? _kNoSurah,
                              isExpanded: true,
                              // The first choice records only the amount, and
                              // is how a picked surah is taken back.
                              items: [
                                DropdownMenuItem<int>(
                                  value: _kNoSurah,
                                  child: AppText(
                                    _kNoSurahChoice,
                                    style: AppTextStyles.labelMd.copyWith(
                                      color: AppColors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                                ...kSurahs.map(
                                  (s) => DropdownMenuItem<int>(
                                    value: s.number,
                                    child: AppText(s.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  _onSurahChanged(v == _kNoSurah ? null : v),
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
                        onChanged: (type) =>
                            setState(() => _selectedType = type),
                      ),
                      SizedBox(height: 12.h),

                      AppText(
                        'طريقة العد',
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      if (_isHadith) ...[
                        SegmentedSelector<_HadithUnit>(
                          options: const [
                            SegmentOption(
                              value: _HadithUnit.pages,
                              label: 'صفحات',
                            ),
                            SegmentOption(
                              value: _HadithUnit.hadiths,
                              label: 'أحاديث',
                            ),
                          ],
                          selected: _hadithUnit,
                          onChanged: _onHadithUnitChanged,
                        ),
                        SizedBox(height: 12.h),
                      ] else ...[
                        SegmentedSelector<_AmountUnit>(
                          options: const [
                            SegmentOption(
                              value: _AmountUnit.surah,
                              label: 'سورة',
                            ),
                            SegmentOption(
                              value: _AmountUnit.hizb,
                              label: 'حزب',
                            ),
                            SegmentOption(
                              value: _AmountUnit.pages,
                              label: 'صفحات',
                            ),
                            SegmentOption(
                              value: _AmountUnit.ayahs,
                              label: 'آيات',
                            ),
                          ],
                          selected: _unit,
                          onChanged: _onUnitChanged,
                        ),
                        SizedBox(height: 12.h),
                      ],

                      if (_countsAyahRange)
                        _buildAyahRange()
                      else ...[
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
                                    keyboardType:
                                        TextInputType.numberWithOptions(
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
                                    onTap: () => _amountController.selection =
                                        TextSelection(
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
                        ] else if (_countsAyahs) ...[
                          SizedBox(height: 6.h),
                          AppText(
                            'لكتابة أرقام الآيات (من آية – إلى آية) اختر السورة',
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
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
            ],
          ),
        ),
      ),
    );
  }
}

/// One end of an ayah range: a label over a centred number box styled like
/// the page counter, so the two ways of counting look like one sheet.
class _AyahField extends StatefulWidget {
  const _AyahField({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool hasError;
  final ValueChanged<String> onChanged;

  @override
  State<_AyahField> createState() => _AyahFieldState();
}

class _AyahFieldState extends State<_AyahField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.hasError
        ? AppColors.error
        : _focus.hasFocus
        ? AppColors.inputFocusBorder
        : AppColors.inputBorder;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          widget.label,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6.h),
        AnimatedContainer(
          duration: AppConstants.animFast,
          height: 48.h,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.enabled
                ? AppColors.surfaceContainerLow
                : AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: borderColor),
          ),
          child: Semantics(
            label: widget.label,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                MemorizationAmountInputFormatter(allowHalf: false),
              ],
              // Select-all on tap: typing "20" replaces the 1 rather than
              // making 120.
              onTap: () => widget.controller.selection = TextSelection(
                baseOffset: 0,
                extentOffset: widget.controller.text.length,
              ),
              onChanged: widget.onChanged,
              style: AppTextStyles.bodyMdBold.copyWith(
                color: widget.enabled
                    ? AppColors.onSurface
                    : AppColors.onSurfaceVariant,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
