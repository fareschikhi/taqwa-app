import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/surahs.dart';
import '../../../../core/enums/memorization_type.dart';
import '../../../../core/providers/selected_student_provider.dart';
import '../../../../core/utils/memorization_history.dart';
import '../../../../core/utils/hadith_label.dart';
import '../../../data/repositories/student_repository.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/pushed_page_back_button.dart';
import '../widgets/parent_chat_button.dart';
import 'package:taqwa/core/utils/memorization_amount.dart';
import 'package:taqwa/core/utils/ayah_range.dart' show kAyahUnitLabel;
import 'package:taqwa/core/utils/progress_totals.dart';
import 'package:taqwa/core/widgets/memorization_totals_card.dart';

class ChildProgressPage extends ConsumerStatefulWidget {
  /// With no arguments the page follows the parent's (or adult student's)
  /// selected child, as a tab of their shell, and lists the latest
  /// [kRecentMemorizationLimit] entries. Staff open it for one student from
  /// the student's profile by passing [studentId] and [studentName]; it is
  /// then a pushed page with a back button, and lists every entry — the
  /// profile already shows the latest ones, so this is where the rest live.
  const ChildProgressPage({super.key, this.studentId, this.studentName})
    : assert(
        (studentId == null) == (studentName == null),
        'Pass studentId and studentName together, or neither.',
      );

  final int? studentId;
  final String? studentName;

  @override
  ConsumerState<ChildProgressPage> createState() => _ChildProgressPageState();
}

class _ChildProgressPageState extends ConsumerState<ChildProgressPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  Map<String, dynamic>? _progress;
  List<Map<String, dynamic>> _history = [];

  /// Opened for one student by staff, rather than as the parent's tab.
  bool get _isForOneStudent => widget.studentId != null;

  /// How many entries the list shows: all of them for staff, the latest few
  /// for a parent.
  int get _historyLimit =>
      _isForOneStudent ? _history.length : kRecentMemorizationLimit;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id =
          widget.studentId ?? ref.read(selectedStudentProvider).selected?.id;
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
        _repo.getMemorizationProgress(childId),
        _repo.getMemorizationHistory(childId),
      ]);
      if (mounted) {
        setState(() {
          _progress = results[0] as Map<String, dynamic>;
          _history = results[1] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int studentId;
    final String studentName;
    if (_isForOneStudent) {
      studentId = widget.studentId!;
      studentName = widget.studentName!;
    } else {
      final child = ref.watch(selectedStudentProvider).selected;

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
      studentId = child.id;
      studentName = child.fullName;
    }

    final totalPagesDone = formatAmount(_progress?['totalPagesDone'] as num?);
    final totalSurahs = (_progress?['totalSurahs'] as num?)?.toInt() ?? 0;
    final typeCounts =
        (_progress?['typeCounts'] as Map<String, dynamic>?) ?? {};
    final newCount = (typeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;
    final minorCount = (typeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0;
    final majorCount = (typeCounts['BIGREVISION'] as num?)?.toInt() ?? 0;
    final hadithTypeCounts =
        (_progress?['hadithTypeCounts'] as Map<String, dynamic>?) ?? {};
    final hadithNewCount =
        (hadithTypeCounts['MEMORIZING'] as num?)?.toInt() ?? 0;
    final hadithMinorCount =
        (hadithTypeCounts['SMALLREVISION'] as num?)?.toInt() ?? 0;
    final hadithMajorCount =
        (hadithTypeCounts['BIGREVISION'] as num?)?.toInt() ?? 0;
    // Hadith history stays visible after the admin turns hadith off.
    final showHadith =
        _progress?['tracksHadith'] == true ||
        hadithNewCount + hadithMinorCount + hadithMajorCount > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(studentId),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    SizedBox(height: 16.h),
                    Row(
                      children: [
                        if (_isForOneStudent)
                          const PushedPageBackButton()
                        else
                          const ParentChatButton(),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: AppText(
                            'تقدم المدرسة القرآنية',
                            textAlign: TextAlign.right,
                            style: AppTextStyles.headlineLgMobile.copyWith(
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    AppText(
                      'تتبع رحلة $studentName في حفظ القرآن الكريم.',
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    if (_isLoading)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 60.h),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      )
                    else ...[
                      _SummaryCard(
                        pagesLabel: totalPagesDone,
                        pages: (_progress?['totalPagesDone'] as num?) ?? 0,
                        ayahs: (_progress?['totalAyahsDone'] as num?) ?? 0,
                        totalSurahs: totalSurahs,
                      ),
                      // Hadith is its own subject with its own units, so it
                      // gets its own card rather than a line on the Quran one.
                      if (showHadith) ...[
                        SizedBox(height: 12.h),
                        MemorizationTotalsCard(
                          title: 'الحديث الشريف',
                          icon: Icons.auto_stories_outlined,
                          totals: hadithTotals(
                            hadiths: _progress?['totalHadithsDone'] as num?,
                            pages: _progress?['totalHadithPagesDone'] as num?,
                          ),
                        ),
                      ],
                      SizedBox(height: 20.h),
                      // The headings only matter once there are two rows.
                      if (showHadith) const _StatsHeading('القرآن الكريم'),
                      _TypeCountsRow(
                        newCount: newCount,
                        minorCount: minorCount,
                        majorCount: majorCount,
                      ),
                      if (showHadith) ...[
                        SizedBox(height: 16.h),
                        const _StatsHeading('الحديث الشريف'),
                        _TypeCountsRow(
                          newCount: hadithNewCount,
                          minorCount: hadithMinorCount,
                          majorCount: hadithMajorCount,
                        ),
                      ],
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          // Say the list is trimmed, so an older entry that is
                          // missing does not read as lost data.
                          if (_history.length > _historyLimit)
                            AppText(
                              'آخر $_historyLimit إدخالات',
                              style: AppTextStyles.labelSm.copyWith(
                                color: AppColors.onSurfaceVariant,
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
                      if (_history.isEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 16.h),
                          child: AppText(
                            'لا يوجد سجل حفظ بعد',
                            style: AppTextStyles.bodyMd.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        )
                      else
                        // One card with dividers rather than a card per
                        // row: ten entries read as one list, not ten things.
                        AppCard(
                          padding: EdgeInsets.symmetric(horizontal: 16.w),
                          borderRadius: AppConstants.radiusLg,
                          child: Column(
                            children: [
                              for (final (i, entry) in recentMemorization(
                                _history,
                                limit: _historyLimit,
                              ).indexed) ...[
                                if (i > 0)
                                  const Divider(color: AppColors.cardBorder),
                                _buildRecordItem(entry),
                              ],
                            ],
                          ),
                        ),
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

  Widget _buildRecordItem(Map<String, dynamic> entry) {
    // An unrecognised type falls back to new memorization, matching the
    // column default on the server.
    final type =
        MemorizationTypeX.fromApi(entry['memorizationType'] as String?) ??
        MemorizationType.hifz;
    final typeLabel = type == MemorizationType.hifz ? 'حفظ جديد' : type.label;
    final isHadith = entry['subject'] == 'HADITH';
    final referenceLabel = isHadith
        ? hadithLabelOrFallback(entry['hadithReference'] as String?)
        : surahLabelOf((entry['surahNumber'] as num?)?.toInt());
    String dateStr = '';
    try {
      final dt = DateTime.parse(
        (entry['date'] ?? entry['recordedAt']).toString(),
      );
      dateStr =
          '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      dateStr = '';
    }

    final (typeColor, typeTint) = _typeColors(type);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        children: [
          // One line always: a wrapped "حفظ جديد" was the Stitch export's
          // one visible flaw.
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: typeTint,
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: AppText(
              typeLabel,
              maxLines: 1,
              softWrap: false,
              style: AppTextStyles.labelMdBold.copyWith(color: typeColor),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusSm,
                        ),
                      ),
                      child: AppText(
                        recordAmountText(entry),
                        maxLines: 1,
                        style: AppTextStyles.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: AppText(
                        referenceLabel,
                        textAlign: TextAlign.end,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMdBold.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                AppText(
                  dateStr,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Text colour and tint for a memorization type, shared by the tiles and the
/// history pills so one type always wears one colour.
(Color, Color) _typeColors(MemorizationType type) => switch (type) {
  MemorizationType.hifz => (AppColors.primaryDark, AppColors.primaryContainer),
  MemorizationType.minorReview => (
    AppColors.secondary,
    AppColors.secondaryContainer,
  ),
  _ => (AppColors.tertiary, AppColors.tertiaryContainer),
};

class _StatsHeading extends StatelessWidget {
  const _StatsHeading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AppText(
            text,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(width: 8.w),
          Container(
            width: 8.w,
            height: 8.w,
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

class _TypeCountsRow extends StatelessWidget {
  const _TypeCountsRow({
    required this.newCount,
    required this.minorCount,
    required this.majorCount,
  });
  final int newCount, minorCount, majorCount;

  @override
  Widget build(BuildContext context) {
    // Right to left: new memorization is read first.
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            label: 'مراجعة وضبط',
            value: '$majorCount',
            color: AppColors.tertiary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _MiniStat(
            label: 'جمع',
            value: '$minorCount',
            color: AppColors.secondary,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: _MiniStat(
            label: 'حفظ جديد',
            value: '$newCount',
            color: AppColors.primaryDark,
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: AppText(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          AppText(
            value,
            style: AppTextStyles.headlineMd.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Pages in the Madinah mushaf, the whole Quran.
const int kQuranPages = 604;

/// The hero of the tab: pages memorised, surahs touched, and how far that is
/// through the whole Quran.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.pagesLabel,
    required this.pages,
    required this.ayahs,
    required this.totalSurahs,
  });

  final String pagesLabel;
  final num pages;

  /// Ayahs memorized by range. Their own unit: they are named under the page
  /// count and never added to it or to the bar.
  final num ayahs;
  final int totalSurahs;

  @override
  Widget build(BuildContext context) {
    // A page entered twice as new memorisation can push the sum past the
    // mushaf; the bar stops full rather than overflowing.
    final ratio = (pages / kQuranPages).clamp(0.0, 1.0).toDouble();
    final percent = (ratio * 100).round();

    return Container(
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
      padding: EdgeInsets.all(20.w),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.menu_book,
                  color: AppColors.onPrimary,
                  size: 32.w,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AppText(
                        'صفحة منجزة',
                        style: AppTextStyles.bodyMdBold.copyWith(
                          color: AppColors.onPrimary,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AppText(
                        pagesLabel,
                        style: AppTextStyles.headlineLg.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (ayahs > 0)
                    AppText(
                      '+ ${formatAmount(ayahs)} $kAyahUnitLabel',
                      style: AppTextStyles.bodyMdBold.copyWith(
                        color: AppColors.onPrimary,
                      ),
                    ),
                  AppText(
                    '$totalSurahs سورة تم تناولها',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Container(
              height: 1,
              color: AppColors.onPrimary.withValues(alpha: 0.2),
            ),
          ),
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: AppColors.onPrimary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: AppText(
                  '$percent%',
                  textDirection: TextDirection.ltr,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
              const Spacer(),
              AppText(
                '$pagesLabel / $kQuranPages صفحة',
                style: AppTextStyles.labelMdBold.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          Semantics(
            label: 'تم حفظ $percent بالمئة من القرآن الكريم',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
              // The app tree is LTR; an Arabic reader expects the bar to
              // fill from the right.
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 8.h,
                  backgroundColor: AppColors.gradientEnd.withValues(alpha: 0.6),
                  valueColor: const AlwaysStoppedAnimation(AppColors.onPrimary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
