import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/selected_student_provider.dart';
import '../../../data/repositories/student_repository.dart';
import '../../../data/models/attendance_summary_model.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import '../widgets/parent_chat_button.dart';

class ChildAttendanceHistoryPage extends ConsumerStatefulWidget {
  const ChildAttendanceHistoryPage({super.key});

  @override
  ConsumerState<ChildAttendanceHistoryPage> createState() =>
      _ChildAttendanceHistoryPageState();
}

class _ChildAttendanceHistoryPageState
    extends ConsumerState<ChildAttendanceHistoryPage> {
  final _repo = StudentRepository();
  bool _isLoading = true;
  int? _loadedChildId;
  AttendanceSummaryModel? _summary;
  List<Map<String, dynamic>> _history = [];

  /// The timeline opens on the last month; anything older waits behind a
  /// button so a long record does not bury the days a parent came to see.
  bool _showOlder = false;

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
      // A pull-to-refresh keeps the older days open; another child starts
      // folded again.
      if (childId != _loadedChildId) _showOlder = false;
      _loadedChildId = childId;
    });
    try {
      final results = await Future.wait([
        _repo.getAttendanceSummary(childId),
        _repo.getAttendanceHistory(childId),
      ]);
      if (mounted) {
        setState(() {
          _summary = results[0] as AttendanceSummaryModel;
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => _load(child.id),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(height: 16.h),
                Row(
                  children: [
                    const ParentChatButton(),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: AppText(
                        'سجل الحضور التفصيلي',
                        textAlign: TextAlign.right,
                        style: AppTextStyles.headlineLgMobile.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),
                AppText(
                  'سجلات حضور ${child.fullName} وغيابه.',
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
                  // The boxes report the current month; the timeline under
                  // them reaches back further, so the heading says which is
                  // which rather than leaving a bare count to be read as
                  // an all-time figure.
                  AppText(
                    'إحصائيات هذا الشهر',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  // Right to left: attendance is read first.
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          label: 'أيام الغياب',
                          value: '${_summary?.monthAbsent ?? 0}',
                          color: AppColors.absent,
                          icon: Icons.cancel_outlined,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: _StatBox(
                          label: 'أيام الحضور',
                          value: '${_summary?.monthAttended ?? 0}',
                          color: AppColors.present,
                          icon: Icons.check_circle_outline,
                        ),
                      ),
                    ],
                  ),
                  // Its own line rather than a third box: the streak spans
                  // the whole record, not just this month, so it does not
                  // belong in a row of monthly figures.
                  if ((_summary?.currentStreak ?? 0) > 0) ...[
                    SizedBox(height: 10.h),
                    _StreakCard(days: _summary?.currentStreak ?? 0),
                  ],
                  SizedBox(height: 8.h),
                  // A late day sits in the حضور box while the timeline still
                  // shows it as متأخر, so the rule is spelled out rather than
                  // left for a parent to work out from counts that look off.
                  AppText(
                    'أيام التأخر تُحتسب ضمن الحضور.',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  _MonthCalendar(history: _history),
                  SizedBox(height: 24.h),
                  AppText(
                    'السجل الزمني',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  if (_history.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      child: AppText(
                        'لا يوجد سجل حضور بعد',
                        style: AppTextStyles.bodyMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    ..._buildTimeline(),
                ],
                SizedBox(height: 32.h),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The last month's days, then a button that reveals the older ones below
  /// it — below, so the button stays where it was tapped.
  List<Widget> _buildTimeline() {
    final now = DateTime.now();
    // Same day last month; DateTime rolls month 0 back to December.
    final cutoff = DateTime(now.year, now.month - 1, now.day);
    bool isOld(Map<String, dynamic> record) {
      final dt = DateTime.tryParse(record['date'].toString());
      // An unreadable date is kept in view rather than hidden as old.
      return dt != null && DateTime(dt.year, dt.month, dt.day).isBefore(cutoff);
    }

    final recent = _history.where((r) => !isOld(r)).toList();
    final older = _history.where(isOld).toList();

    return [
      if (recent.isEmpty)
        Padding(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          child: AppText(
            'لا يوجد سجل حضور خلال الشهر الأخير',
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ...recent.map(_buildRecordRow),
      if (older.isNotEmpty) ...[
        SizedBox(height: 4.h),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => setState(() => _showOlder = !_showOlder),
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.surfaceContainerLowest,
              side: const BorderSide(color: AppColors.cardBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusLg),
              ),
            ),
            icon: Icon(
              _showOlder ? Icons.expand_less : Icons.history,
              size: 20.w,
              color: AppColors.onSurfaceVariant,
            ),
            label: AppText(
              _showOlder
                  ? 'إخفاء السجل الأقدم'
                  : 'عرض السجل الأقدم (${older.length})',
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ),
        if (_showOlder) ...[
          SizedBox(height: 10.h),
          ...older.map(_buildRecordRow),
        ],
      ],
    ];
  }

  Widget _buildRecordRow(Map<String, dynamic> record) {
    final status = AttendanceStatusStyle.of(record['status'] as String?);
    final dt = DateTime.tryParse(record['date'].toString());
    final dateStr = dt == null
        ? (record['date'] ?? '').toString()
        : '${dt.day.toString().padLeft(2, '0')}/'
              '${dt.month.toString().padLeft(2, '0')}/${dt.year}';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.subtle,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (dt != null)
                AppText(
                  kArabicWeekdays[dt.weekday - 1],
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              AppText(
                dateStr,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const Spacer(),
          AppText(
            status.label,
            style: AppTextStyles.bodyMdBold.copyWith(color: status.color),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: status.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(status.icon, color: status.color, size: 20.w),
          ),
        ],
      ),
    );
  }
}

/// Weekday names indexed by [DateTime.weekday] - 1 (Monday first).
const List<String> kArabicWeekdays = [
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

const List<String> _kArabicMonths = [
  'جانفي',
  'فيفري',
  'مارس',
  'أفريل',
  'ماي',
  'جوان',
  'جويلية',
  'أوت',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// Label, colour and icon of an attendance status: one vocabulary for the
/// timeline, the calendar and its legend.
class AttendanceStatusStyle {
  const AttendanceStatusStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;

  static const present = AttendanceStatusStyle(
    'حاضر',
    AppColors.present,
    Icons.check,
  );
  static const late = AttendanceStatusStyle(
    'متأخر',
    AppColors.late,
    Icons.schedule,
  );
  static const excused = AttendanceStatusStyle(
    'عذر',
    AppColors.excused,
    Icons.event_busy_outlined,
  );
  static const absent = AttendanceStatusStyle(
    'غائب',
    AppColors.absent,
    Icons.close,
  );

  static AttendanceStatusStyle of(String? status) => switch (status) {
    'PRESENT' => present,
    'LATE' => late,
    'EXCUSED' => excused,
    _ => absent,
  };
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label, value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20.w),
              ),
              const Spacer(),
              AppText(
                label,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(height: 10.h),
          // No unit word: the label already says these are days.
          AppText(
            value,
            style: AppTextStyles.headlineLg.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                AppText(
                  'أيام',
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                SizedBox(width: 6.w),
                AppText(
                  '$days',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          AppText(
            'أيام حضور متتالية',
            style: AppTextStyles.bodyMdBold.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Icon(
              Icons.local_fire_department,
              color: AppColors.late,
              size: 24.w,
            ),
          ),
        ],
      ),
    );
  }
}

/// A month at a glance: one dot per marked day, coloured by status.
///
/// Opens on the current month and pages back as far as the record reaches.
/// Saturday first and right to left, the way an Algerian week is read.
class _MonthCalendar extends StatefulWidget {
  const _MonthCalendar({required this.history});

  final List<Map<String, dynamic>> history;

  @override
  State<_MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<_MonthCalendar> {
  late DateTime _month = _thisMonth();

  static DateTime _thisMonth() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  /// Status of each marked day, keyed by date with the time stripped.
  Map<DateTime, AttendanceStatusStyle> get _byDay => {
    for (final r in widget.history)
      if (DateTime.tryParse(r['date'].toString()) case final dt?)
        DateTime(dt.year, dt.month, dt.day): AttendanceStatusStyle.of(
          r['status'] as String?,
        ),
  };

  DateTime get _earliest {
    final days = _byDay.keys;
    if (days.isEmpty) return _thisMonth();
    final first = days.reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime(first.year, first.month);
  }

  void _shift(int months) =>
      setState(() => _month = DateTime(_month.year, _month.month + months));

  @override
  Widget build(BuildContext context) {
    final byDay = _byDay;
    final canGoBack = _month.isAfter(_earliest);
    final canGoForward = _month.isBefore(_thisMonth());

    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // Columns from the right: Saturday is column 0. DateTime.weekday has
    // Monday = 1 … Saturday = 6, Sunday = 7.
    final leading = (DateTime(_month.year, _month.month).weekday + 1) % 7;
    final cells = [
      ...List<int?>.filled(leading, null),
      for (var d = 1; d <= daysInMonth; d++) d,
    ];
    final today = DateTime.now();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // RTL: the left-pointing arrow moves forward in time.
              _NavArrow(
                icon: Icons.chevron_left,
                tooltip: 'الشهر التالي',
                onTap: canGoForward ? () => _shift(1) : null,
              ),
              SizedBox(width: 8.w),
              _NavArrow(
                icon: Icons.chevron_right,
                tooltip: 'الشهر السابق',
                onTap: canGoBack ? () => _shift(-1) : null,
              ),
              const Spacer(),
              AppText(
                '${_kArabicMonths[_month.month - 1]} ${_month.year}',
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.calendar_month_outlined,
                color: AppColors.primary,
                size: 22.w,
              ),
            ],
          ),
          SizedBox(height: 12.h),
          // Laid out right to left so Saturday sits at the right edge.
          Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                Row(
                  children: [
                    for (final name in const [
                      'سبت',
                      'أحد',
                      'اثنين',
                      'ثلاثاء',
                      'أربعاء',
                      'خميس',
                      'جمعة',
                    ])
                      Expanded(
                        child: AppText(
                          name,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
                const Divider(color: AppColors.cardBorder, height: 16),
                for (var row = 0; row * 7 < cells.length; row++)
                  Row(
                    children: [
                      for (var col = 0; col < 7; col++)
                        Expanded(
                          child: _DayCell(
                            day: row * 7 + col < cells.length
                                ? cells[row * 7 + col]
                                : null,
                            month: _month,
                            byDay: byDay,
                            today: today,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(color: AppColors.cardBorder, height: 20),
          // The legend reads right to left like the grid.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final s in const [
                AttendanceStatusStyle.absent,
                AttendanceStatusStyle.excused,
                AttendanceStatusStyle.late,
                AttendanceStatusStyle.present,
              ])
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      s.label,
                      style: AppTextStyles.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
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

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.byDay,
    required this.today,
  });

  final int? day;
  final DateTime month;
  final Map<DateTime, AttendanceStatusStyle> byDay;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final day = this.day;
    if (day == null) return SizedBox(height: 48.h);

    final date = DateTime(month.year, month.month, day);
    final status = byDay[date];
    final isToday =
        date.year == today.year &&
        date.month == today.month &&
        date.day == today.day;

    return Semantics(
      label: status == null ? '$day' : '$day، ${status.label}',
      child: Container(
        height: 48.h,
        margin: EdgeInsets.all(2.w),
        decoration: isToday
            ? BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                border: Border.all(color: AppColors.primary),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppText(
              '$day',
              style: AppTextStyles.labelMdBold.copyWith(
                color: status == null && !isToday
                    ? AppColors.outline
                    : AppColors.onSurface,
                fontWeight: status == null && !isToday
                    ? FontWeight.w500
                    : FontWeight.w700,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: status?.color ?? Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({required this.icon, required this.tooltip, this.onTap});

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SizedBox(
            width: 40.w,
            height: 40.w,
            child: Icon(
              icon,
              size: 22.w,
              color: enabled ? AppColors.onSurface : AppColors.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
