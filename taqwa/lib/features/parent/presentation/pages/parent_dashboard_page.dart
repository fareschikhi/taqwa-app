import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/widgets/wird_reminder_card.dart';
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
import 'package:taqwa/core/widgets/app_logo.dart';
import 'package:taqwa/core/widgets/halaqa_news_card.dart';
import 'package:taqwa/core/widgets/student_of_month_card.dart';
import 'package:taqwa/features/data/models/student_of_month_model.dart';
import 'package:taqwa/features/data/repositories/student_of_month_repository.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';
import 'package:taqwa/features/data/repositories/halaqa_announcement_repository.dart';
import 'package:taqwa/features/shared/presentation/pages/halaqa_news_page.dart';
import 'package:taqwa/core/utils/memorization_amount.dart';

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
              _buildAppBar(),
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 20.h),
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
                    if (WirdReminderCard.isAvailable) ...[
                      SizedBox(height: 20.h),
                      const WirdReminderCard(),
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
            const ParentChatButton(),
            const Spacer(),
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

  Widget _buildGreeting(String parentName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          parentName.isNotEmpty ? 'أهلاً، $parentName' : 'أهلاً بك',
          style: AppTextStyles.headlineLgMobile.copyWith(
            color: AppColors.onBackground,
          ),
        ),
        SizedBox(height: 4.h),
        AppText(
          'تابع تقدم أبنائك في حفظ القرآن الكريم.',
          style: AppTextStyles.bodyMd.copyWith(
            color: AppColors.onSurfaceVariant,
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
    final pagesDone = formatAmount(_progress?['totalPagesDone'] as num?);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ChildDetailsPage()),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [AppColors.primary, AppColors.secondary],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'عرض التفاصيل',
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_back_ios,
                      color: AppColors.onPrimary,
                      size: 16,
                    ),
                  ],
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      child.fullName,
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    AppText(
                      child.halaqaName ?? 'غير مسجل في حلقة',
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onPrimary.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                AvatarWidget(
                  avatarUrl: child.avatar,
                  size: 56.w,
                  backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
                  fallback: AppText(
                    child.fullName.isNotEmpty ? child.fullName[0] : '؟',
                    style: AppTextStyles.headlineMd.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.onPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              // How much of the Qur'an the child has memorised, whether they
              // have been turning up lately, and the teacher's overall rating.
              // Revision counts belong to the teacher's view of the work, not
              // to a parent's summary of it.
              child: Row(
                children: [
                  Expanded(
                    child: _StatChip(
                      label: 'أيام الحضور هذا الشهر',
                      value: _isLoading ? '--' : '$monthAttendedDays',
                      onTap: () => _openTab(2),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _StatChip(
                      label: 'حفظ',
                      value: _isLoading ? '--' : '$pagesDone صفحة',
                      onTap: () => _openTab(1),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40.h,
                    color: AppColors.onPrimary.withValues(alpha: 0.3),
                  ),
                  Expanded(
                    child: _StatChip(
                      label: 'التقييم العام',
                      value: _isLoading ? '--' : (_rating ?? 'لم يقيّم بعد'),
                    ),
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
                    color: AppColors.primary,
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
        AppText(
          label,
          style: AppTextStyles.labelSm.copyWith(
            color: AppColors.onPrimary.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );
}
