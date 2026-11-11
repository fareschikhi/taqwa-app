import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/note_timeline.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/selected_student_provider.dart';
import '../../../../core/utils/last_session.dart';
import '../../../../core/utils/student_rating.dart';
import '../../../../core/widgets/last_session_card.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/attendance_summary_model.dart';
import '../../../data/models/parent/parent_child_model.dart';
import '../../../data/models/student_note_model.dart';
import 'child_details_page.dart';
import 'child_notes_page.dart';
import '../widgets/parent_chat_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/shell_tab_scope.dart';
import 'package:taqwa/core/widgets/halaqa_news_card.dart';
import 'package:taqwa/core/widgets/student_of_month_card.dart';
import 'package:taqwa/features/data/models/student_of_month_model.dart';
import 'package:taqwa/features/data/repositories/student_of_month_repository.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/shared/presentation/pages/halaqa_news_page.dart';
import 'package:taqwa/core/utils/progress_totals.dart';

/// How many of the child's latest notes the dashboard shows before "عرض الكل".
const int kNotesPreviewCount = 3;

class ParentDashboardPage extends ConsumerStatefulWidget {
  const ParentDashboardPage({super.key});

  @override
  ConsumerState<ParentDashboardPage> createState() =>
      _ParentDashboardPageState();
}

class _ParentDashboardPageState extends ConsumerState<ParentDashboardPage> {
  final _repo = StudentRepository();
  final _newsRepo = HalaqaAnnouncementRepository();
  final _monthRepo = StudentOfMonthRepository();
  List<StudentOfMonthModel> _picks = [];
  bool _isLoading = true;
  int? _loadedChildId;
  AttendanceSummaryModel? _attendance;
  Map<String, dynamic>? _progress;
  List<StudentNoteModel> _notes = [];
  List<Map<String, dynamic>> _attendanceHistory = [];
  List<HalaqaAnnouncementModel> _news = [];
  String? _rating;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = ref.read(selectedStudentProvider).selected?.id;
      if (id != null) _load(id);
    });
  }

  Future<void> _load(int childId) async {
    setState(() {
      _isLoading = true;
      _loadedChildId = childId;
    });
    try {
      final results = await Future.wait([
        _repo.getAttendanceSummary(childId),
        _repo.getMemorizationProgress(childId),
        _repo.getProfile(childId),
        _repo.getAttendanceHistory(childId),
      ]);
      final profile = results[2] as Map<String, dynamic>;
      final rawNotes = (profile['notes'] as List?) ?? [];
      final news = await _newsRepo.myAnnouncements().catchError(
        (_) => <HalaqaAnnouncementModel>[],
      );
      // One call covers every child's halaqa; the card picks the selected
      // child's at build time. A failure only leaves the card off.
      final picks = await _monthRepo.mine().catchError(
        (_) => <StudentOfMonthModel>[],
      );
      // The parent may have switched child while this was in flight. The
      // newer load owns the page; this one must not paint the previous
      // child's notes and figures under the new child's name.
      if (childId != _loadedChildId) return;
      if (mounted) {
        setState(() {
          _attendance = results[0] as AttendanceSummaryModel;
          _progress = results[1] as Map<String, dynamic>;
          _notes = rawNotes
              .cast<Map<String, dynamic>>()
              .map(StudentNoteModel.fromJson)
              .toList();
          _attendanceHistory = results[3] as List<Map<String, dynamic>>;
          _rating = ratingOf(profile);
          _news = news;
          _picks = picks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted && childId == _loadedChildId) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// The selected child's halaqa's طالب الشهر, or nothing while its teacher
  /// has not validated one.
  List<Widget> _buildStudentOfMonth(ParentChildModel child) {
    final pick = _picks.where((p) => p.halaqaId == child.halaqaId).firstOrNull;
    if (pick == null) return const [];
    return [
      StudentOfMonthCard(
        pick: pick,
        isViewer: pick.studentId == child.id,
        viewerIsParent: true,
      ),
      SizedBox(height: 20.h),
    ];
  }

  Future<void> _openNews() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HalaqaNewsPage()));
  }

  @override
  Widget build(BuildContext context) {
    final childState = ref.watch(selectedStudentProvider);
    final child = childState.selected;
    final parentName = ref.watch(authProvider).user?.fullName ?? '';

    ref.listen(selectedStudentProvider, (previous, next) {
      final id = next.selected?.id;
      if (id != null && id != _loadedChildId) _load(id);
    });

    if (child == null) {
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
          onRefresh: () => _load(child.id),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16.h),
                    _buildGreeting(parentName),
                    SizedBox(height: 24.h),
                    _buildChildCard(context, child),
                    SizedBox(height: 20.h),
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
                      ..._buildStudentOfMonth(child),
                      _buildLastSession(),
                      SizedBox(height: 20.h),
                      if (_news.isNotEmpty) ...[
                        HalaqaNewsCard(
                          announcements: _news,
                          onSeeAll: _openNews,
                        ),
                        SizedBox(height: 20.h),
                      ],
                      _buildTeacherNotes(child),
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

  /// The chat button sits beside the greeting instead of on a bar of its
  /// own, so the page starts one row higher.
  Widget _buildGreeting(String parentName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ParentChatButton(),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                parentName.isNotEmpty ? 'أهلاً، $parentName' : 'أهلاً بك',
                textAlign: TextAlign.right,
                style: AppTextStyles.headlineLgMobile.copyWith(
                  color: AppColors.onBackground,
                ),
              ),
              SizedBox(height: 4.h),
              AppText(
                'تابع تقدم أبنائك في حفظ القرآن الكريم.',
                textAlign: TextAlign.right,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Each figure opens the bottom-nav tab behind it, ahead of the card's own
  /// tap to the details page; the indexes match ParentShell._pages.
  void _openTab(int index) => ShellTabScope.of(context)?.selectTab(index);

  Widget _buildChildCard(BuildContext context, ParentChildModel child) {
    // The card reports the current month; the attendance history tab keeps
    // showing the whole enrolment, which is why both figures are available.
    final monthAttendedDays = _attendance?.monthAttended ?? 0;
    // Pages and ayahs are separate units, so each takes its own line.
    final quranDone = totalsText(
      quranTotals(
        pages: _progress?['totalPagesDone'] as num?,
        ayahs: _progress?['totalAyahsDone'] as num?,
      ),
      separator: '\n',
    );

    Widget divider() => Container(
      width: 1,
      height: 40.h,
      color: AppColors.onPrimary.withValues(alpha: 0.25),
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChildDetailsPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Two faint rings for depth; decoration only.
            const _HeroRing(top: -50, left: -40, size: 160),
            const _HeroRing(bottom: -70, right: -30, size: 180),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                children: [
                  Row(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.arrow_back,
                            color: AppColors.onPrimary,
                            size: 18.w,
                          ),
                          SizedBox(width: 6.w),
                          AppText(
                            'عرض التفاصيل',
                            style: AppTextStyles.labelMdBold.copyWith(
                              color: AppColors.onPrimary,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            AppText(
                              child.fullName,
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.headlineSm.copyWith(
                                color: AppColors.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6.h),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12.w,
                                vertical: 3.h,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.onPrimary.withValues(
                                  alpha: 0.18,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull,
                                ),
                              ),
                              child: AppText(
                                child.halaqaName ?? 'غير مسجل في حلقة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.labelMdBold.copyWith(
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: const BoxDecoration(
                          color: AppColors.onPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: AvatarWidget(
                          avatarUrl: child.avatar,
                          size: 60.w,
                          backgroundColor: AppColors.primaryContainer,
                          fallback: AppText(
                            child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                            style: AppTextStyles.headlineMd.copyWith(
                              color: AppColors.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: Container(
                      height: 1,
                      color: AppColors.onPrimary.withValues(alpha: 0.2),
                    ),
                  ),
                  // How much of the Qur'an the child has memorised, whether
                  // they have been turning up lately, and the teacher's
                  // overall rating. Revision counts belong to the teacher's
                  // view of the work, not to a parent's summary of it.
                  // Laid out right to left: attendance is read first.
                  Row(
                    children: [
                      Expanded(
                        child: _StatChip(
                          label: 'التقييم العام',
                          value: _isLoading
                              ? '--'
                              : (_rating ?? 'لم يقيّم بعد'),
                        ),
                      ),
                      divider(),
                      Expanded(
                        child: _StatChip(
                          label: 'حفظ',
                          value: _isLoading ? '--' : quranDone,
                          onTap: () => _openTab(1),
                        ),
                      ),
                      divider(),
                      Expanded(
                        child: _StatChip(
                          label: 'أيام الحضور هذا الشهر',
                          value: _isLoading ? '--' : '$monthAttendedDays',
                          onTap: () => _openTab(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A parent opening the app wants to know how the last halaqa went, which a
  /// running count of sessions never told them. The memorization shown is the
  /// one recorded on the day of that attendance, so the two cannot disagree.
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

  Widget _buildTeacherNotes(ParentChildModel child) {
    // A short preview, like the news card: the dashboard is a summary, and
    // the full history is one tap away on the child's own notes page.
    final preview = _notes.take(kNotesPreviewCount).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          children: [
            // The profile carries at most five notes, so any note beyond the
            // preview may have more behind it; the page reads the history.
            if (_notes.length > preview.length)
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChildNotesPage(
                      studentId: child.id,
                      childName: child.fullName,
                    ),
                  ),
                ),
                child: AppText(
                  'عرض الكل',
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            const Spacer(),
            AppText(
              'ملاحظات المعلم',
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ],
        ),
        SizedBox(height: 12.h),
        if (_notes.isEmpty)
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
          NoteTimeline(notes: preview),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, this.onTap});
  final String label, value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: [
        AppText(
          value,
          // A rating is free text a teacher typed, so it may run longer than
          // a number does.
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2.h),
        // Full white: these 12sp labels sit on green, where any
        // transparency drops them under readable contrast.
        AppText(
          label,
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm.copyWith(color: AppColors.onPrimary),
        ),
      ],
    ),
  );
}

/// A faint white ring on a hero card, for depth.
class _HeroRing extends StatelessWidget {
  const _HeroRing({
    required this.size,
    this.top,
    this.bottom,
    this.left,
    this.right,
  });

  final double size;
  final double? top, bottom, left, right;

  @override
  Widget build(BuildContext context) => Positioned(
    top: top,
    bottom: bottom,
    left: left,
    right: right,
    child: IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.onPrimary.withValues(alpha: 0.06),
        ),
      ),
    ),
  );
}
