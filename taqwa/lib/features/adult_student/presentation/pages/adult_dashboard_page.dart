import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/providers/selected_student_provider.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/last_session.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/app_logo.dart';
import 'package:taqwa/core/widgets/fine_balance_card.dart';
import 'package:taqwa/core/widgets/halaqa_news_card.dart';
import 'package:taqwa/core/widgets/last_session_card.dart';
import 'package:taqwa/features/data/models/attendance_summary_model.dart';
import 'package:taqwa/features/data/models/fine/fine_summary_model.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/fine_repository.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/data/repositories/student_repository.dart';
import 'package:taqwa/features/shared/presentation/pages/halaqa_news_page.dart';
import 'fines_history_page.dart';

/// The adult student's own front page. There is no child to pick a card for
/// here — the record loaded is always his — so this reads like
/// `ParentDashboardPage` with the guardianship stripped out and his balance
/// given the top spot a parent's screen has no equivalent for.
class AdultDashboardPage extends ConsumerStatefulWidget {
  const AdultDashboardPage({super.key});

  @override
  ConsumerState<AdultDashboardPage> createState() => _AdultDashboardPageState();
}

class _AdultDashboardPageState extends ConsumerState<AdultDashboardPage> {
  final _studentRepo = StudentRepository();
  final _fineRepo = FineRepository();
  final _newsRepo = HalaqaAnnouncementRepository();

  bool _isLoading = true;
  int? _loadedStudentId;
  AttendanceSummaryModel? _attendance;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _attendanceHistory = [];
  List<Map<String, dynamic>> _notes = [];
  FineSummaryModel? _fines;
  List<HalaqaAnnouncementModel> _news = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(selectedStudentProvider).selected?.id;
      if (id != null) _load(id);
    });
  }

  Future<void> _load(int studentId) async {
    setState(() {
      _isLoading = true;
      _loadedStudentId = studentId;
    });
    try {
      final results = await Future.wait([
        _studentRepo.getAttendanceSummary(studentId),
        _studentRepo.getMemorizationProgress(studentId),
        _studentRepo.getAttendanceHistory(studentId),
        // If the profile fetch fails, return an empty map so the dashboard still
        // loads with balance and attendance; notes will be empty, not missing.
        _studentRepo
            .getProfile(studentId)
            .catchError((_) => <String, dynamic>{}),
        _fineRepo.forStudent(studentId),
      ]);
      final profile = results[3] as Map<String, dynamic>;
      final rawNotes = (profile['notes'] as List?) ?? [];
      final news = await _newsRepo.myAnnouncements().catchError(
        (_) => <HalaqaAnnouncementModel>[],
      );
      if (mounted) {
        setState(() {
          _attendance = results[0] as AttendanceSummaryModel;
          _progress = results[1] as Map<String, dynamic>;
          _attendanceHistory = results[2] as List<Map<String, dynamic>>;
          _notes = rawNotes.cast<Map<String, dynamic>>();
          _fines = results[4] as FineSummaryModel;
          _news = news;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNews() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HalaqaNewsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final studentState = ref.watch(selectedStudentProvider);
    final self = studentState.selected;
    final userName = ref.watch(authProvider).user?.fullName ?? '';

    ref.listen(selectedStudentProvider, (previous, next) {
      final id = next.selected?.id;
      if (id != null && id != _loadedStudentId) _load(id);
    });

    if (self == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SizedBox.shrink(),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(self.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              _buildAppBar(),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 20.h),
                    _buildGreeting(userName),
                    SizedBox(height: 24.h),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.h),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      _buildFineBalance(),
                      SizedBox(height: 20.h),
                      if (_news.isNotEmpty) ...[
                        HalaqaNewsCard(
                          announcements: _news,
                          onSeeAll: _openNews,
                        ),
                        SizedBox(height: 20.h),
                      ],
                      _buildSummary(),
                      SizedBox(height: 20.h),
                      _buildLastSession(),
                      SizedBox(height: 20.h),
                      _buildTeacherNotes(),
                    ],
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

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 56.h,
      flexibleSpace: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            const Spacer(),
            Container(
              width: 36.w,
              height: 36.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: AppColors.onPrimaryContainer,
                size: 20.w,
              ),
            ),
            SizedBox(width: 8.w),
            AppText(
              'التقوى',
              style: AppTextStyles.headlineMd.copyWith(
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 6.w),
            AppLogo(height: 30.w),
          ],
        ),
      ),
    );
  }

  Widget _buildGreeting(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          userName.isNotEmpty ? 'أهلاً، $userName' : 'أهلاً بك',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.onBackground,
          ),
        ),
        SizedBox(height: 4.h),
        AppText(
          'تابع حفظك وحضورك ورصيدك.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFineBalance() {
    final fines = _fines;
    if (fines == null) return const SizedBox.shrink();

    return FineBalanceCard(
      summary: fines,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => FinesHistoryPage(summary: fines)),
      ),
    );
  }

  /// The same two figures a parent's hero card leads with — how much of the
  /// Qur'an is memorised, and whether he has been turning up — without the
  /// gradient hero that exists on the parent's side only to be a tappable
  /// route to a *child's* details page.
  Widget _buildSummary() {
    final monthAttendedDays = _attendance?.monthAttended ?? 0;
    final pagesDone = (_progress?['totalPagesDone'] as num?)?.toInt() ?? 0;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatChip(
              label: 'أيام الحضور هذا الشهر',
              value: '$monthAttendedDays',
            ),
          ),
          Container(width: 1, height: 40.h, color: AppColors.outlineVariant),
          Expanded(
            child: _StatChip(label: 'حفظ', value: '$pagesDone صفحة'),
          ),
        ],
      ),
    );
  }

  /// A student opening the app wants to know how the last halaqa went, which
  /// a running count of sessions never told him. The memorization shown is
  /// the one recorded on the day of that attendance, so the two cannot
  /// disagree.
  Widget _buildLastSession() {
    final records =
        (_progress?['records'] as List?)?.cast<Map<String, dynamic>>() ??
        const <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          'آخر حضور',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(height: 12.h),
        LastSessionCard(
          session: lastSessionOf(
            attendance: _attendanceHistory,
            memorization: records,
          ),
        ),
      ],
    );
  }

  Widget _buildTeacherNotes() {
    return TeacherNotesSection(notes: _notes);
  }
}

class TeacherNotesSection extends StatelessWidget {
  const TeacherNotesSection({super.key, required this.notes});
  final List<Map<String, dynamic>> notes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          'ملاحظات المعلم',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(height: 12.h),
        if (notes.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: AppText(
              'لا توجد ملاحظات بعد',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          )
        else
          ...notes.map((n) {
            String displayDate = '';
            try {
              final dt = DateTime.parse(n['createdAt'] as String);
              displayDate = '${dt.day}/${dt.month}/${dt.year}';
            } catch (_) {
              displayDate = (n['createdAt'] ?? '').toString();
            }
            final teacherName =
                (n['teacher'] as Map<String, dynamic>?)?['user']
                    as Map<String, dynamic>? ??
                {};

            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: AppCard(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        AppText(
                          displayDate,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.outline,
                          ),
                        ),
                        const Spacer(),
                        AppText(
                          (teacherName['fullName'] as String?) ?? '',
                          style: AppTextStyles.labelMdBold.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      (n['note'] as String?) ?? '',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      AppText(
        value,
        style: AppTextStyles.headlineSm.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      AppText(
        label,
        style: AppTextStyles.labelSm.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
