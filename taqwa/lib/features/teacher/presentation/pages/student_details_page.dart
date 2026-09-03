import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/utils/fine_balance.dart';
import '../../../../core/utils/hadith_label.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/widgets/fine_balance_card.dart';
import '../../../data/models/fine/fine_summary_model.dart';
import '../../../data/repositories/fine_repository.dart';
import '../../../data/repositories/halaqa_repository.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/teacher_student_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class StudentDetailsPage extends StatefulWidget {
  const StudentDetailsPage({super.key, required this.student});
  final TeacherStudentModel student;

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
  final _repo = StudentRepository();
  final _halaqaRepo = HalaqaRepository();
  final _fineRepo = FineRepository();

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

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
      final results = await Future.wait([
        _repo.getProfile(widget.student.id),
        _repo.getMemorizationProgress(widget.student.id),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0];
        _progress = results[1];
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
    final halaqaId = widget.student.halaqaId;
    if (halaqaId == null) return;
    try {
      final halaqa = await _halaqaRepo.getHalaqa(halaqaId);
      if (!mounted || !halaqa.isAdult) return;
      final summary = await _fineRepo.forStudent(widget.student.id);
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

  /// The teacher words the rating themselves, so this is a free-text field
  /// rather than a picker. Submitting an empty box clears the rating.
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
      await _repo.updateStudent(widget.student.id, {'currentRating': rating});
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
                      if (_isAdultStudent && _fineSummary != null) ...[
                        SizedBox(height: 16.h),
                        _buildFinesSection(),
                      ],
                      SizedBox(height: 20.h),
                      _buildLastSessionCard(),
                      SizedBox(height: 16.h),
                      _buildHistoryCard(),
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
    // Revision amounts are hizbs, so the server counts pages from new
    // memorization only — this is a page count, not a share of the Quran.
    final pagesDone = (_progress?['totalPagesDone'] as num?)?.toInt() ?? 0;
    final attendanceRate = (_profile?['attendanceRate'] as num?)?.toInt() ?? 0;

    // IntrinsicHeight bounds the row's height so the boxes can stretch to match
    // each other. Without it the row is unbounded inside the sliver and stretch
    // hands its children an infinite height, which aborts layout.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StatBox(
              label: 'الصفحات المحفوظة',
              value: '$pagesDone',
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _StatBox(
              label: 'الحضور',
              value: '$attendanceRate%',
              color: AppColors.secondary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _StatBox(
              label: 'التقييم العام',
              value: _currentRating ?? 'لم يقيّم بعد',
              color: AppColors.tertiary,
              isMuted: _currentRating == null,
              onTap: _editRating,
            ),
          ),
        ],
      ),
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
        FineBalanceCard(summary: summary),
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
        studentId: widget.student.id,
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(FineRepository.errorMessage(e))),
      );
    }
  }

  /// There is no assignment model behind a "current task", so this reports the
  /// most recent recitation instead of inventing a target to measure against.
  Widget _buildLastSessionCard() {
    final records = _records;
    if (records.isEmpty) return const SizedBox.shrink();

    final entry = records.first;
    final type =
        MemorizationTypeX.fromApi(entry['memorizationType'] as String?) ??
        MemorizationType.hifz;
    final amount = (entry['amountDone'] as num?)?.toInt() ?? 0;
    final typeLabel = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
    final isHadith = entry['subject'] == 'HADITH';
    final referenceLabel = isHadith
        ? hadithLabelOrFallback(entry['hadithReference'] as String?)
        : surahLabelOf((entry['surahNumber'] as num?)?.toInt());

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
            '$typeLabel · $amount ${isHadith ? 'حديث' : type.unitLabel}',
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

  Widget _buildHistoryCard() {
    final records = _records;
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            'سجل الحفظ والمراجعة',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
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
    final name = (user?['fullName'] as String?) ?? widget.student.fullName;
    final avatar = (user?['avatar'] as String?) ?? widget.student.avatar;
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
    this.isMuted = false,
  });
  final String label, value;
  final Color color;
  final VoidCallback? onTap;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    final valueColor = isMuted ? AppColors.onSurfaceVariant : color;
    return GestureDetector(
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
                if (onTap != null) ...[
                  Icon(
                    Icons.edit_outlined,
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
    );
  }
}

class _RecordItem extends StatelessWidget {
  const _RecordItem({
    required this.date,
    required this.surah,
    required this.type,
    required this.amount,
  });
  final String date, surah, type, amount;

  /// An unrecognised type falls back to new memorization, matching the
  /// column default on the server.
  factory _RecordItem.fromEntry(Map<String, dynamic> entry) {
    final type =
        MemorizationTypeX.fromApi(entry['memorizationType'] as String?) ??
        MemorizationType.hifz;
    final count = (entry['amountDone'] as num?)?.toInt() ?? 0;
    final isHadith = entry['subject'] == 'HADITH';
    return _RecordItem(
      date: _formatDate(entry['date'] ?? entry['recordedAt']),
      surah: isHadith
          ? hadithLabelOrFallback(entry['hadithReference'] as String?)
          : surahLabelOf((entry['surahNumber'] as num?)?.toInt()),
      type: type == MemorizationType.hifz ? 'حفظ جديد' : type.label,
      amount: '$count ${isHadith ? 'حديث' : type.unitLabel}',
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
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                surah,
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Row(
                children: [
                  AppText(
                    date,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.outline,
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Container(
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
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
        : reason.isEmpty
        ? 'أدخل سبب التعديل'
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
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onSurface,
          ),
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
                label: 'السبب',
                controller: _reasonController,
                maxLines: 2,
              ),
              if (_errorText != null) ...[
                SizedBox(height: 8.h),
                AppText(
                  _errorText!,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.error,
                  ),
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
            child: AppText('حفظ', style: AppTextStyles.button.copyWith(color: accent)),
          ),
        ],
      ),
    );
  }
}
