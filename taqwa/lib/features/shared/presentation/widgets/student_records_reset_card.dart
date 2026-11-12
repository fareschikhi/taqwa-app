import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/widgets/app_text.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../data/models/student/student_records_summary_model.dart';
import '../../../data/repositories/student_repository.dart';

/// The admin's "danger zone" on the student form: three independent buttons
/// that wipe the student's attendance, memorization or points.
///
/// Nothing is deleted when a button is tapped. The tap starts an [undoWindow]
/// — the row switches to an inline "تراجع" and a snackbar offers the same —
/// and the DELETE request goes out only once the window has run out. So an
/// undo never has to rebuild deleted rows, and if the app dies mid-window
/// nothing is lost: the failure mode is "not deleted", never "deleted by
/// mistake".
///
/// The timers deliberately outlive this widget: an admin who taps Save (and
/// so leaves the page) inside the window still gets the deletion, and can
/// still undo it from the snackbar, which moves to the previous screen.
class StudentRecordsResetCard extends StatefulWidget {
  const StudentRecordsResetCard({super.key, required this.studentId});

  final int studentId;

  static const undoWindow = Duration(seconds: 8);

  @override
  State<StudentRecordsResetCard> createState() =>
      _StudentRecordsResetCardState();
}

enum _LoadState { loading, loaded, failed }

class _StudentRecordsResetCardState extends State<StudentRecordsResetCard> {
  final _repo = StudentRepository();

  StudentRecordsSummary? _summary;
  _LoadState _load = _LoadState.loading;

  /// Kinds inside their undo window, each with the timer that will delete.
  final Map<StudentRecordKind, Timer> _pending = {};

  /// Kinds whose DELETE request is in flight.
  final Set<StudentRecordKind> _deleting = {};

  /// Kinds cleared during this visit — shown as empty even before a reload.
  final Set<StudentRecordKind> _cleared = {};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _load = _LoadState.loading);
    try {
      final summary = await _repo.getRecordsSummary(widget.studentId);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _load = _LoadState.loaded;
      });
    } catch (_) {
      if (mounted) setState(() => _load = _LoadState.failed);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────

  void _requestClear(StudentRecordKind kind) {
    // Captured now: the root messenger outlives this page, so the timer can
    // still report a failure after the admin has left it.
    final messenger = ScaffoldMessenger.of(context);

    final timer = Timer(
      StudentRecordsResetCard.undoWindow,
      () => _commit(kind, messenger),
    );
    setState(() => _pending[kind] = timer);

    // Newest first: a snackbar queued behind another one would show its undo
    // too late. An earlier clear keeps its inline undo in its own row.
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: AppText('سيُمسح ${_copy(kind).title} لهذا الطالب'),
          duration: StudentRecordsResetCard.undoWindow,
          // A snackbar with an action stays up until tapped unless told
          // otherwise; this one must leave with its window.
          persist: false,
          action: SnackBarAction(
            label: 'تراجع',
            onPressed: () => _undo(kind, messenger, fromSnackBar: true),
          ),
        ),
      );
  }

  void _undo(
    StudentRecordKind kind,
    ScaffoldMessengerState messenger, {
    bool fromSnackBar = false,
  }) {
    final timer = _pending.remove(kind);
    // Already gone: the window ran out between the frame and the tap.
    if (timer == null) return;
    timer.cancel();
    if (mounted) setState(() {});

    if (!fromSnackBar) messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: AppText('تم التراجع — لم يُمسح ${_copy(kind).title}'),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _commit(
    StudentRecordKind kind,
    ScaffoldMessengerState messenger,
  ) async {
    _pending.remove(kind);
    if (mounted) setState(() => _deleting.add(kind));

    try {
      await _repo.clearRecords(widget.studentId, kind);
      if (mounted) setState(() => _cleared.add(kind));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            'تعذّر مسح ${_copy(kind).title}: ${StudentRepository.errorMessage(e)}',
          ),
        ),
      );
    } finally {
      _deleting.remove(kind);
      if (mounted) setState(() {});
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: AppText(
                  'إعادة تعيين السجلات',
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
              SizedBox(width: 8.w),
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 22.w,
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppText(
            'يُنفَّذ المسح دون الحاجة إلى حفظ التعديلات، ويمكنك التراجع خلال '
            '${StudentRecordsResetCard.undoWindow.inSeconds} ثوانٍ. '
            'كل زر مستقل: مسح الحضور أو الحفظ لا يمسح النقاط المكتسبة منهما.',
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
            textAlign: TextAlign.end,
          ),
          SizedBox(height: 12.h),
          for (final kind in StudentRecordKind.values) ...[
            if (kind != StudentRecordKind.values.first)
              const Divider(height: 1, color: AppColors.outlineVariant),
            _buildRow(kind),
          ],
          if (_load == _LoadState.failed) ...[
            SizedBox(height: 4.h),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: _loadSummary,
                icon: const Icon(Icons.refresh, size: 18),
                label: AppText(
                  'تعذّر تحميل الأعداد — إعادة المحاولة',
                  style: AppTextStyles.labelMd,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(StudentRecordKind kind) {
    final copy = _copy(kind);
    final pending = _pending.containsKey(kind);
    final deleting = _deleting.contains(kind);
    final isEmpty =
        _cleared.contains(kind) ||
        (_summary != null && _summary!.countOf(kind) == 0);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12.h),
      child: Column(
        children: [
          Row(
            children: [
              _buildAction(
                kind,
                pending: pending,
                deleting: deleting,
                isEmpty: isEmpty,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      copy.title,
                      style: AppTextStyles.labelMdBold.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    SizedBox(height: 2.h),
                    AppText(
                      _status(
                        kind,
                        pending: pending,
                        deleting: deleting,
                        isEmpty: isEmpty,
                      ),
                      style: AppTextStyles.labelSm.copyWith(
                        color: pending
                            ? AppColors.error
                            : AppColors.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              Container(
                width: 40.w,
                height: 40.w,
                decoration: BoxDecoration(
                  color: isEmpty
                      ? AppColors.surfaceContainerLow
                      : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Icon(
                  copy.icon,
                  size: 20.w,
                  color: isEmpty
                      ? AppColors.onSurfaceVariant
                      : AppColors.onErrorContainer,
                ),
              ),
            ],
          ),
          // How much of the undo window is left, draining right to left.
          if (pending) ...[
            SizedBox(height: 10.h),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 1, end: 0),
              duration: StudentRecordsResetCard.undoWindow,
              builder: (_, value, _) => ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  color: AppColors.error,
                  backgroundColor: AppColors.errorContainer,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(
    StudentRecordKind kind, {
    required bool pending,
    required bool deleting,
    required bool isEmpty,
  }) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
    );
    final minSize = Size(0, 44.h);

    if (deleting) {
      return SizedBox(
        width: 44.h,
        height: 44.h,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.error,
          ),
        ),
      );
    }

    if (pending) {
      return OutlinedButton.icon(
        onPressed: () => _undo(kind, ScaffoldMessenger.of(context)),
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          foregroundColor: AppColors.primaryDark,
          side: const BorderSide(color: AppColors.primaryDark),
        ),
        icon: const Icon(Icons.undo, size: 18),
        label: AppText('تراجع', style: AppTextStyles.labelMdBold),
      );
    }

    // Disabled until the counts arrive, unless they failed to: a broken
    // summary must not lock the admin out of the reset itself.
    final canClear = !isEmpty && _load != _LoadState.loading;
    return OutlinedButton.icon(
      onPressed: canClear ? () => _requestClear(kind) : null,
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        shape: shape,
        foregroundColor: AppColors.error,
        side: BorderSide(
          color: canClear
              ? AppColors.error.withValues(alpha: 0.6)
              : AppColors.outlineVariant,
        ),
      ),
      icon: const Icon(Icons.delete_sweep_outlined, size: 18),
      label: AppText(_copy(kind).button, style: AppTextStyles.labelMdBold),
    );
  }

  String _status(
    StudentRecordKind kind, {
    required bool pending,
    required bool deleting,
    required bool isEmpty,
  }) {
    if (deleting) return 'جارٍ المسح…';
    if (pending) return 'سيُمسح بعد لحظات — اضغط «تراجع» للإلغاء';
    if (isEmpty) return 'لا توجد سجلات';
    final summary = _summary;
    if (summary == null) {
      return _load == _LoadState.loading ? 'جارٍ التحميل…' : '—';
    }
    if (kind == StudentRecordKind.points) {
      return 'الرصيد: ${_formatPoints(summary.pointsTotal)} · '
          'عدد القيود: ${summary.points}';
    }
    return 'عدد السجلات: ${summary.countOf(kind)}';
  }

  /// 7.0 → "7", 7.25 → "7.25": points are kept to a thousandth.
  String _formatPoints(double v) {
    final s = v.toStringAsFixed(3);
    return s.replaceFirst(RegExp(r'\.?0+$'), '');
  }

  static ({String title, String button, IconData icon}) _copy(
    StudentRecordKind kind,
  ) => switch (kind) {
    StudentRecordKind.attendance => (
      title: 'سجل الحضور',
      button: 'مسح الحضور',
      icon: Icons.event_available_outlined,
    ),
    StudentRecordKind.memorization => (
      title: 'سجل الحفظ والمراجعة',
      button: 'مسح الحفظ',
      icon: Icons.menu_book_outlined,
    ),
    StudentRecordKind.points => (
      title: 'النقاط',
      button: 'مسح النقاط',
      icon: Icons.stars_outlined,
    ),
  };
}
