import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_widget.dart';
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

  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _progress;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = StudentRepository.errorMessage(e);
        _isLoading = false;
      });
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
            surahLabelOf((entry['surahNumber'] as num?)?.toInt()),
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          AppText(
            '$typeLabel · $amount ${type.unitLabel}',
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
    return _RecordItem(
      date: _formatDate(entry['date'] ?? entry['recordedAt']),
      surah: surahLabelOf((entry['surahNumber'] as num?)?.toInt()),
      type: type == MemorizationType.hifz ? 'حفظ جديد' : type.label,
      amount: '$count ${type.unitLabel}',
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
