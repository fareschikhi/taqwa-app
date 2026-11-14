import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/utils/extra_phones.dart';
import '../../../../core/utils/fine_balance.dart';
import '../../../../core/utils/record_type_label.dart';
import '../../../../core/utils/hadith_label.dart'
    show recordAmountText, hadithLabelOrFallback;
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/fine_balance_card.dart';
import '../../../data/models/attendance_summary_model.dart';
import '../../../data/models/fine/fine_summary_model.dart';
import '../../../data/repositories/fine_repository.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/repositories/parent_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../adult_student/presentation/pages/fines_history_page.dart';
import '../../../parent/presentation/pages/child_attendance_history_page.dart';
import '../../../parent/presentation/pages/child_progress_page.dart';
import '../widgets/profile_detail_widgets.dart';
import 'parent_form_page.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/utils/progress_totals.dart';
import 'package:taqwa/core/widgets/memorization_totals_card.dart';
import 'package:taqwa/core/widgets/points_section.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({
    super.key,
    required this.studentId,
    required this.fullName,
    this.avatar,
    this.halaqaId,
    this.canEditParent = false,
    this.canEditRating = false,
    this.canAdjustPoints = false,
    this.canDeleteRecords = false,
  });

  /// What the caller already knows before this page's own load lands: the id
  /// it fetches with, the halaqa that decides whether fines apply, and a name
  /// and avatar for the header in the meantime. Everything else on screen
  /// comes from `GET students/:id/profile`, which every role that opens this
  /// page is allowed to call.
  final int studentId;
  final String fullName;
  final String? avatar;
  final int? halaqaId;

  /// Whether tapping the parent card opens that parent's edit form. Only the
  /// admin's student list turns this on; every other role sees the same card
  /// as read-only contact details.
  final bool canEditParent;

  /// Whether the overall rating box opens the edit dialog. The admin's and a
  /// teacher's student lists turn this on; a manager (and anyone reaching the
  /// page through a parent's linked students) only reads the rating, and the
  /// server refuses it from a manager anyway.
  final bool canEditRating;

  /// Whether the points card carries a `تعديل النقاط` button. The staff
  /// student lists (admin, teacher, manager) turn it on; the server still
  /// refuses a student outside the caller's halaqa.
  final bool canAdjustPoints;

  /// Whether the full memorization and attendance histories this page opens
  /// let each entry be deleted, for one recorded by mistake. The admin's and
  /// a teacher's student lists turn it on — the two roles that record them;
  /// the server still refuses a teacher outside the student's halaqa.
  final bool canDeleteRecords;

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  final _repo = StudentRepository();
  final _halaqaRepo = HalaqaRepository();
  final _fineRepo = FineRepository();
  final _pointsRepo = PointsRepository();

  /// Every student has points, child or adult. Staff outside the student's
  /// halaqa are refused by the server, and the section then simply stays
  /// off. It loads itself, and a reload of the page (which swaps the list for
  /// a spinner) builds it afresh.
  final _parentRepo = ParentRepository();
  bool _isOpeningParent = false;

  /// The registration details (health, family situation…) stay folded until
  /// asked for, so they are not on screen every time the profile opens.
  bool _showRegistration = false;

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

  /// Attendance is read from its own endpoint rather than the profile, because
  /// the profile only carries an all-time figure and the page reports the
  /// current month.
  AttendanceSummaryModel? _attendance;

  // `GET /students/:id/profile` nests only `name`, `level` and the teacher
  // for the halaqa — not `isAdult` — so whether this student can carry a fine
  // is resolved from a second call rather than read off the profile.
  bool _isAdultStudent = false;
  FineSummaryModel? _fineSummary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _repo.getProfile(widget.studentId),
        _repo.getMemorizationProgress(widget.studentId),
        _repo.getAttendanceSummary(widget.studentId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Map<String, dynamic>;
        _progress = results[1] as Map<String, dynamic>;
        _attendance = results[2] as AttendanceSummaryModel;
        _isLoading = false;
      });
      // Runs after the profile is on screen: a halaqa lookup failing (or a
      // student with no halaqa at all) must not blank a page that already
      // loaded — the fines section simply stays off.
      await _loadFines();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = StudentRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFines() async {
    final halaqaId = widget.halaqaId;
    if (halaqaId == null) return;
    try {
      final halaqa = await _halaqaRepo.getHalaqa(halaqaId);
      if (!mounted || !halaqa.isAdult) return;
      final summary = await _fineRepo.forStudent(widget.studentId);
      if (!mounted) return;
      setState(() {
        _isAdultStudent = true;
        _fineSummary = summary;
      });
    } catch (_) {
      // A child never accrues a fine, and an unreachable halaqa reads the
      // same way here: no fines section rather than an error banner over a
      // page whose other sections loaded fine.
    }
  }

  /// Whoever opens the page words the rating themselves, so this is a
  /// free-text field rather than a picker. Submitting an empty box clears it.
  Future<void> _editRating() async {
    final controller = TextEditingController(text: _currentRating ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: AppText(
            'التقييم العام',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: 'مثال: ممتاز، جيد جداً، يحتاج مراجعة',
              hintStyle: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
            ),
            onSubmitted: (v) => Navigator.pop(dialogContext, v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: AppText(
                'إلغاء',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: AppText(
                'حفظ',
                style: AppTextStyles.button.copyWith(color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );

    if (saved == null) return;
    final rating = saved.trim();
    try {
      await _repo.updateStudent(widget.studentId, {'currentRating': rating});
      if (!mounted) return;
      // Patched in place so the box updates without a second round trip; a
      // later refresh reads the stored value back anyway.
      setState(() => _profile?['currentRating'] = rating);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StudentRepository.errorMessage(e))),
      );
    }
  }

  String? get _currentRating {
    final raw = _profile?['currentRating'] as String?;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Map<String, dynamic>? get _halaqa =>
      _profile?['halaqa'] as Map<String, dynamic>?;

  /// The profile's parent `user` block — name, phone and avatar. Null for an
  /// adult student, who is his own guardian and has no parent row at all; the
  /// card is left out entirely rather than filled with a placeholder, which
  /// would read as a parent the school failed to record.
  Map<String, dynamic>? get _parent =>
      _parentRow?['user'] as Map<String, dynamic>?;

  /// The profile's whole parent row: [_parent] plus the parent's `address`,
  /// which lives on the parent rather than on the user.
  Map<String, dynamic>? get _parentRow =>
      _profile?['parent'] as Map<String, dynamic>?;

  /// The profile only nests the parent's contact fields, while the edit form
  /// needs the whole row (email, address, linked children), so the parent is
  /// fetched by the student's `parentId` before the form opens. The profile
  /// is reloaded afterwards in case the name, phone or photo changed.
  Future<void> _openParent() async {
    final parentId = (_profile?['parentId'] as num?)?.toInt();
    if (parentId == null || _isOpeningParent) return;
    setState(() => _isOpeningParent = true);
    try {
      final parent = await _parentRepo.getParent(parentId);
      if (!mounted) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => ParentFormPage(parent: parent)),
      );
      if (saved == true && mounted) await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ParentRepository.errorMessage(e))));
    } finally {
      if (mounted) setState(() => _isOpeningParent = false);
    }
  }

  Widget _buildParentCard(Map<String, dynamic> parent) {
    final name = (parent['fullName'] as String?) ?? '';
    final phone = parent['phone'] as String?;
    final canOpen = widget.canEditParent;

    return AppCard(
      padding: EdgeInsets.all(16.w),
      onTap: canOpen ? _openParent : null,
      child: Row(
        children: [
          AvatarWidget(
            avatarUrl: parent['avatar'] as String?,
            size: 44.w,
            fallback: AppText(
              name.isNotEmpty ? name[0] : '؟',
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'ولي الأمر',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 2.h),
                AppText(
                  name,
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone != null && phone.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  AppText(
                    phone,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ],
              ],
            ),
          ),
          if (canOpen)
            _isOpeningParent
                ? SizedBox(
                    width: 20.w,
                    height: 20.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : Icon(
                    Icons.chevron_left,
                    color: AppColors.onSurfaceVariant,
                    size: 20.w,
                  ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _records =>
      ((_profile?['memorization'] as List<dynamic>?) ?? const [])
          .cast<Map<String, dynamic>>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText(
                            _error!,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          TextButton(
                            onPressed: _load,
                            child: AppText(
                              'إعادة المحاولة',
                              style: AppTextStyles.button.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      SizedBox(height: 20.h),
                      _buildStatsRow(),
                      if (_parent != null) ...[
                        SizedBox(height: 16.h),
                        _buildParentCard(_parent!),
                      ],
                      PointsSection(
                        load: () => _pointsRepo.forStudent(widget.studentId),
                        canAdjust: widget.canAdjustPoints,
                        padding: EdgeInsets.only(top: 16.h),
                      ),
                      if (_isAdultStudent && _fineSummary != null) ...[
                        SizedBox(height: 16.h),
                        _buildFinesSection(),
                      ],
                      SizedBox(height: 20.h),
                      _buildProgressSection(),
                      SizedBox(height: 20.h),
                      _buildLastSessionCard(),
                      SizedBox(height: 16.h),
                      _buildHistoryCard(),
                      SizedBox(height: 16.h),
                      _buildRegistrationCard(),
                      SizedBox(height: 32.h),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    // Revision re-reads pages already memorized, so the server counts pages
    // from new memorization only — this is a page count, not a share of the
    // Quran.
    // Pages and ayahs are separate units, so each takes its own line.
    final quranDone = totalsText(
      quranTotals(
        pages: _progress?['totalPagesDone'] as num?,
        ayahs: _progress?['totalAyahsDone'] as num?,
      ),
      separator: '\n',
    );
    final attendedDays = _attendance?.monthAttended ?? 0;

    // IntrinsicHeight bounds the row's height so the boxes can stretch to match
    // each other. Without it the row is unbounded inside the sliver and stretch
    // hands its children an infinite height, which aborts layout.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBox(
              label: 'المحفوظ من القرآن',
              value: quranDone,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _StatBox(
              label: 'أيام الحضور هذا الشهر',
              value: '$attendedDays',
              color: AppColors.secondary,
              onTap: _openAttendanceHistory,
              actionIcon: Icons.chevron_left,
              semanticsHint: 'عرض سجل الحضور',
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _StatBox(
              label: 'التقييم العام',
              value: _currentRating ?? 'لم يقيّم بعد',
              color: AppColors.tertiary,
              isMuted: _currentRating == null,
              onTap: widget.canEditRating ? _editRating : null,
              actionIcon: widget.canEditRating ? Icons.edit_outlined : null,
              semanticsHint: widget.canEditRating ? 'تعديل التقييم' : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Everything the student has memorized, one card per subject and a tile
  /// per unit, so any staff member opening the profile sees the whole
  /// picture: «12 صفحة» beside «40 آية», and the hadith totals when the
  /// student has a hadith track (or hadith entries from before it was
  /// turned off).
  Widget _buildProgressSection() {
    final progress = _progress;
    if (progress == null) return const SizedBox.shrink();

    final surahs = (progress['totalSurahs'] as num?)?.toInt() ?? 0;
    final hadithCounts =
        (progress['hadithTypeCounts'] as Map<String, dynamic>?) ?? const {};
    final hasHadithEntries = hadithCounts.values.any((v) => v is num && v > 0);
    final showHadith = progress['tracksHadith'] == true || hasHadithEntries;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppText(
          'تقدم الحفظ',
          textAlign: TextAlign.right,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(height: 12.h),
        MemorizationTotalsCard(
          title: 'القرآن الكريم',
          icon: Icons.menu_book_outlined,
          totals: quranTotals(
            pages: progress['totalPagesDone'] as num?,
            ayahs: progress['totalAyahsDone'] as num?,
          ),
          subtitle: '$surahs سورة تم تناولها',
        ),
        if (showHadith) ...[
          SizedBox(height: 12.h),
          MemorizationTotalsCard(
            title: 'الحديث الشريف',
            icon: Icons.auto_stories_outlined,
            totals: hadithTotals(
              hadiths: progress['totalHadithsDone'] as num?,
              pages: progress['totalHadithPagesDone'] as num?,
            ),
          ),
        ],
      ],
    );
  }

  /// The balance card an adult student sees on his own dashboard, reused
  /// here rather than rebuilt, plus the two actions only a teacher gets:
  /// charging him for something outside the automatic attendance charges, or
  /// reducing what he owes because he paid or it was forgiven.
  Widget _buildFinesSection() {
    final summary = _fineSummary;
    if (summary == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FineBalanceCard(
          summary: summary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FinesHistoryPage(summary: summary),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: 'إضافة رسوم',
                variant: AppButtonVariant.secondary,
                icon: Icons.add_circle_outline,
                onPressed: () => _showFineAdjustDialog('CHARGE'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: AppButton(
                label: 'خصم',
                variant: AppButtonVariant.secondary,
                icon: Icons.remove_circle_outline,
                onPressed: () => _showFineAdjustDialog('REDUCTION'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Opens the amount/reason dialog for a charge or a reduction, validates it
  /// client-side with the same rule the server enforces, submits it, then
  /// reloads the summary so the balance on screen is the balance on the
  /// server rather than a locally-guessed one.
  Future<void> _showFineAdjustDialog(String kind) async {
    final balance = displayedBalance(_fineSummary?.balance ?? 0);
    final result = await showDialog<_FineAdjustResult>(
      context: context,
      builder: (_) => _FineAdjustDialog(kind: kind, balance: balance),
    );
    if (result == null) return;

    try {
      await _fineRepo.adjust(
        studentId: widget.studentId,
        kind: kind,
        amount: result.amount,
        reason: result.reason,
      );
      if (!mounted) return;
      await _loadFines();
    } catch (e) {
      if (!mounted) return;
      // The server is the final authority on the floor: a balance that moved
      // under the teacher between opening the dialog and submitting it comes
      // back as a 400 with its own Arabic message, which belongs on screen
      // as-is rather than behind a generic failure.
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(FineRepository.errorMessage(e))));
    }
  }

  /// What the registration form (استمارة التسجيل) recorded, laid out as the
  /// children's or the adults' form depending on the account's role. Folded
  /// to its title until [_showRegistration]; once open every row shows,
  /// blank ones as "غير مسجل", so a gap in the file is visible.
  Widget _buildRegistrationCard() {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final isAdult = user?['role'] == 'ADULT_STUDENT';
    String? value(String key) => _profile?[key] as String?;

    final birthDate = DateTime.tryParse(value('birthDate') ?? '');
    final married = _profile?['isMarried'] as bool?;

    // A child linked to a parent is reached through that parent, so his
    // address and phones are the parent's. The child's own stored value
    // (from before the form hid it) still shows when the parent has none,
    // under the plain label so the row never claims to be the parent's.
    final parentRow = isAdult ? null : _parentRow;
    final parentUser = isAdult ? null : _parent;
    String? filled(String? v) => (v == null || v.trim().isEmpty) ? null : v;

    final parentAddress = filled(parentRow?['address'] as String?);
    final parentPhone = filled(parentUser?['phone'] as String?);
    final phoneOwner = parentPhone != null ? parentUser : user;
    final phoneLabel = parentPhone != null
        ? 'رقم هاتف ولي الأمر'
        : 'رقم الهاتف';

    final rows = <Widget>[
      DetailInfoRow(
        icon: Icons.calendar_today_outlined,
        label: 'تاريخ الميلاد',
        value: birthDate == null
            ? null
            : '${birthDate.day.toString().padLeft(2, '0')}/'
                  '${birthDate.month.toString().padLeft(2, '0')}/'
                  '${birthDate.year}',
        isLtr: true,
      ),
      DetailInfoRow(
        icon: Icons.location_on_outlined,
        label: parentAddress != null ? 'عنوان ولي الأمر' : 'العنوان',
        value: parentAddress ?? value('address'),
      ),
      DetailInfoRow(
        icon: Icons.phone_outlined,
        label: phoneLabel,
        value: phoneOwner?['phone'] as String?,
        isLtr: true,
      ),
      for (final extra in parseExtraPhones(phoneOwner?['extraPhones']))
        DetailInfoRow(
          icon: Icons.phone_outlined,
          label: 'رقم هاتف إضافي',
          value: extra,
          isLtr: true,
        ),
      if (isAdult)
        DetailInfoRow(
          icon: Icons.email_outlined,
          label: 'البريد الإلكتروني',
          value: user?['email'] as String?,
          isLtr: true,
        ),
      DetailInfoRow(
        icon: Icons.menu_book_outlined,
        label: isAdult ? 'المستوى الدراسي' : 'الصف الدراسي',
        value: value('schoolLevel'),
      ),
      if (isAdult) ...[
        DetailInfoRow(
          icon: Icons.work_outline,
          label: 'المهنة',
          value: value('occupation'),
        ),
        DetailInfoRow(
          icon: Icons.favorite_border,
          label: 'الحالة الاجتماعية',
          value: married == null ? null : (married ? 'متزوج' : 'أعزب'),
        ),
      ] else ...[
        DetailInfoRow(
          icon: Icons.work_outline,
          label: 'مهنة الأب',
          value: value('fatherJob'),
        ),
        DetailInfoRow(
          icon: Icons.work_outline,
          label: 'مهنة الأم',
          value: value('motherJob'),
        ),
      ],
      DetailInfoRow(
        icon: Icons.health_and_safety_outlined,
        label: 'الحالة الصحية',
        value: value('healthStatus'),
      ),
      DetailInfoRow(
        icon: Icons.family_restroom_outlined,
        label: 'الحالة الاجتماعية للأسرة',
        value: value('familyStatus'),
      ),
      DetailInfoRow(
        icon: Icons.schedule_outlined,
        label: 'توقيت النشاطات الخارجية',
        value: value('externalActivities'),
      ),
    ];

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () =>
                    setState(() => _showRegistration = !_showRegistration),
                icon: Icon(
                  _showRegistration
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.primary,
                  size: 20.w,
                ),
                label: AppText(
                  _showRegistration ? 'إخفاء المعلومات' : 'عرض المعلومات',
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              const Spacer(),
              AppText(
                'بيانات التسجيل',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          if (_showRegistration)
            for (final row in rows) ...[SizedBox(height: 12.h), row],
        ],
      ),
    );
  }

  /// There is no assignment model behind a "current task", so this reports the
  /// most recent recitation instead of inventing a target to measure against.
  Widget _buildLastSessionCard() {
    final records = _records;
    if (records.isEmpty) return const SizedBox.shrink();

    final entry = records.first;
    final amount = recordAmountText(entry);
    final typeLabel = recordTypeLabel(entry);
    final isHadith = entry['subject'] == 'HADITH';
    final referenceLabel = isHadith
        ? hadithLabelOrFallback(entry['hadithReference'] as String?)
        : recordSurahLabel(entry);

    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            'آخر تسميع',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 12.h),
          AppText(
            referenceLabel,
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          AppText(
            '$typeLabel · $amount',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 4.h),
          AppText(
            _formatDate(entry['date'] ?? entry['recordedAt']),
            style: AppTextStyles.caption.copyWith(color: AppColors.outline),
          ),
        ],
      ),
    );
  }

  /// The name the header shows: the profile's once it has loaded, the
  /// caller's until then.
  String get _studentName =>
      ((_profile?['user'] as Map<String, dynamic>?)?['fullName'] as String?) ??
      widget.fullName;

  /// The profile only carries the latest recitations; the parent's progress
  /// page, opened for this one student, lists every one of them.
  void _openMemorizationHistory() => _openHistory(
    ChildProgressPage(
      studentId: widget.studentId,
      studentName: _studentName,
      canDelete: widget.canDeleteRecords,
    ),
  );

  /// The stat box only counts this month; the timeline and calendar behind
  /// it reach back to the student's first marked day.
  void _openAttendanceHistory() => _openHistory(
    ChildAttendanceHistoryPage(
      studentId: widget.studentId,
      studentName: _studentName,
      canDelete: widget.canDeleteRecords,
    ),
  );

  /// Whoever can delete there may have changed the totals, the last
  /// recitation, the month's count, points and fines shown here, so the
  /// profile is read again on the way back. Read-only visitors skip it.
  Future<void> _openHistory(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted && widget.canDeleteRecords) await _load();
  }

  Widget _buildHistoryCard() {
    final records = _records;
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              // Only worth offering once there is something to list.
              if (records.isNotEmpty)
                TextButton(
                  onPressed: _openMemorizationHistory,
                  child: AppText(
                    'عرض الكل',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
              const Spacer(),
              AppText(
                'سجل الحفظ والمراجعة',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (records.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12.h),
              child: AppText(
                'لا توجد سجلات بعد',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            )
          else
            ...records.map(_RecordItem.fromEntry),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = _profile?['user'] as Map<String, dynamic>?;
    final name = (user?['fullName'] as String?) ?? widget.fullName;
    final avatar = (user?['avatar'] as String?) ?? widget.avatar;
    final teacherName =
        ((_halaqa?['teacher'] as Map<String, dynamic>?)?['user']
                as Map<String, dynamic>?)?['fullName']
            as String?;
    final level = _halaqa?['level'] as String?;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onPrimary,
                ),
              ),
              const Spacer(),
              AppText(
                'ملف الطالب',
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (level != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.onPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusFull,
                          ),
                        ),
                        child: AppText(
                          level,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onPrimary,
                          ),
                        ),
                      ),
                    SizedBox(height: 4.h),
                    AppText(
                      (_halaqa?['name'] as String?) ?? 'غير مسجل في حلقة',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    AppText(
                      'المعلم: ${teacherName ?? 'غير معين'}',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AvatarWidget(
                    avatarUrl: avatar,
                    size: 64.w,
                    backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
                    fallback: AppText(
                      name.isNotEmpty ? name[0] : '؟',
                      style: AppTextStyles.headlineLgMobile.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  AppText(
                    name,
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatDate(dynamic raw) {
  if (raw == null) return '';
  try {
    final dt = DateTime.parse(raw.toString());
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$d/$m';
  } catch (_) {
    return '';
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.actionIcon,
    this.semanticsHint,
    this.isMuted = false,
  });
  final String label, value;
  final Color color;
  final VoidCallback? onTap;

  /// Small icon beside the label saying what a tap does: a pencil for an
  /// edit, a chevron for a page behind the box.
  final IconData? actionIcon;

  /// What a tap does, for screen readers.
  final String? semanticsHint;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final valueColor = isMuted ? AppColors.onSurfaceVariant : color;
    return Semantics(
      button: onTap != null,
      hint: semanticsHint,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppText(
                value,
                style: AppTextStyles.headlineSm.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (actionIcon != null) ...[
                    Icon(
                      actionIcon,
                      size: 12.sp,
                      color: AppColors.onSurfaceVariant,
                    ),
                    SizedBox(width: 3.w),
                  ],
                  Flexible(
                    child: AppText(
                      label,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecordItem extends StatelessWidget {
  const _RecordItem({
    required this.date,
    required this.surah,
    required this.type,
    required this.amount,
    this.mistakes,
  });
  final String date, surah, type, amount;

  /// A تسميع's الأخطاء, or null on any other entry and on a clean one.
  final String? mistakes;

  factory _RecordItem.fromEntry(Map<String, dynamic> entry) {
    final isHadith = entry['subject'] == 'HADITH';
    return _RecordItem(
      date: _formatDate(entry['date'] ?? entry['recordedAt']),
      surah: isHadith
          ? hadithLabelOrFallback(entry['hadithReference'] as String?)
          : recordSurahLabel(entry),
      type: recordTypeLabel(entry),
      amount: recordAmountText(entry),
      mistakes: recordMistakes(entry),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: AppText(
              amount,
              style: AppTextStyles.labelSm.copyWith(color: AppColors.primary),
            ),
          ),
          SizedBox(width: 12.w),
          // Expanded rather than after a Spacer: an entry naming several
          // surahs has a long label, which must wrap instead of overflowing.
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AppText(
                  surah,
                  textAlign: TextAlign.right,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      date,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.outline,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    // Flexible so a long «تسميع · مراجعة وضبط (اعادة)»
                    // ends in an ellipsis on a narrow phone.
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusFull,
                          ),
                        ),
                        child: AppText(
                          type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (mistakes != null) ...[
                  SizedBox(height: 4.h),
                  AppText(
                    'الأخطاء: $mistakes',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 8.w,
            height: 8.w,
            margin: EdgeInsets.only(top: 6.h),
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// What [_FineAdjustDialog] returns when the teacher confirms. Kept as its
/// own type rather than a plain int so a cancelled dialog (`null`) can never
/// be confused with a submitted amount of zero.
class _FineAdjustResult {
  const _FineAdjustResult({required this.amount, required this.reason});
  final int amount;
  final String reason;
}

/// Amount-and-reason dialog behind both fine actions. A charge and a
/// reduction share one form because the only real difference between them is
/// the title, the accent colour, and which side of [fineAdjustError]'s floor
/// applies — the validation itself is the same pure check the server
/// enforces, run here before the round trip rather than after it.
class _FineAdjustDialog extends StatefulWidget {
  const _FineAdjustDialog({required this.kind, required this.balance});

  /// `'CHARGE'` or `'REDUCTION'` — passed straight through to the repository.
  final String kind;

  /// The balance as it was when the dialog opened. A reduction cannot exceed
  /// it; a fresher value only exists after the server has already answered,
  /// which is why the server check downstream still has the final say.
  final int balance;

  @override
  State<_FineAdjustDialog> createState() => _FineAdjustDialogState();
}

class _FineAdjustDialogState extends State<_FineAdjustDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  String? _errorText;

  bool get _isCharge => widget.kind == 'CHARGE';

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    // A teacher can type anything into this field on a phone keyboard, so a
    // failed parse has to land as the same validation message as any other
    // bad amount rather than throwing.
    final amount = int.tryParse(_amountController.text.trim());
    final reason = _reasonController.text.trim();
    final error = amount == null
        ? 'أدخل مبلغاً أكبر من صفر'
        : fineAdjustError(
            amount: amount,
            kind: widget.kind,
            balance: widget.balance,
          );
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.pop(context, _FineAdjustResult(amount: amount!, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isCharge ? AppColors.error : AppColors.primary;
    final title = _isCharge ? 'إضافة رسوم' : 'خصم من الرصيد';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: AppText(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppTextField(
                label: 'المبلغ (دج)',
                controller: _amountController,
                keyboardType: TextInputType.number,
                autofocus: true,
              ),
              SizedBox(height: 12.h),
              AppTextField(
                label: 'السبب (اختياري)',
                controller: _reasonController,
                maxLines: 2,
              ),
              if (_errorText != null) ...[
                SizedBox(height: 8.h),
                AppText(
                  _errorText!,
                  style: AppTextStyles.labelSm.copyWith(color: AppColors.error),
                  textAlign: TextAlign.end,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: AppText(
              'إلغاء',
              style: AppTextStyles.button.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
          TextButton(
            onPressed: _submit,
            child: AppText(
              'حفظ',
              style: AppTextStyles.button.copyWith(color: accent),
            ),
          ),
        ],
      ),
    );
  }
}
