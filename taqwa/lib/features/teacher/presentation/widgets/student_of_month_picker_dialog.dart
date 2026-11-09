import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_button.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/features/data/models/student_of_month_model.dart';
import 'package:taqwa/features/data/repositories/student_of_month_repository.dart';
import 'package:taqwa/features/teacher/presentation/pages/segmented_selector.dart';

/// The award's accent. Amber reads as "gold" next to the brand teal, and is
/// already the app's warning colour, so no new colour joins the palette.
const Color kAwardColor = AppColors.warning;

enum _Pool { top, others }

/// Asks the teacher to validate last month's طالب الشهر for each halaqa
/// still waiting, one dialog after another.
///
/// Called whenever the teacher enters the app. "لاحقاً" closes it without a
/// choice; it comes back on the next entry until every halaqa is validated,
/// because the server keeps listing a halaqa as pending until then.
class StudentOfMonthPrompt {
  StudentOfMonthPrompt._();

  /// Stops a resume during the first prompt from stacking a second one.
  static bool _showing = false;

  /// A test that ends with the dialog still open never runs the `finally`.
  @visibleForTesting
  static void resetForTest() => _showing = false;

  /// Returns true when at least one pick was validated, so the caller can
  /// refresh whatever shows the card.
  static Future<bool> maybeShow(
    BuildContext context, {
    StudentOfMonthRepository? repository,
  }) async {
    if (_showing) return false;
    _showing = true;
    var validated = false;
    try {
      final repo = repository ?? StudentOfMonthRepository();
      final List<PendingStudentOfMonth> pending;
      try {
        pending = await repo.pending();
      } catch (_) {
        // Offline or a server hiccup: ask again on the next entry rather than
        // interrupting with an error the teacher did not ask for.
        return false;
      }
      for (final item in pending) {
        if (!context.mounted) break;
        final done = await showDialog<bool>(
          context: context,
          // Only the buttons close it, so a stray tap never skips the choice.
          barrierDismissible: false,
          builder: (_) =>
              StudentOfMonthPickerDialog(pending: item, repository: repo),
        );
        if (done == true) {
          validated = true;
        } else {
          // "Later" on one halaqa means later for all of them.
          break;
        }
      }
    } finally {
      _showing = false;
    }
    return validated;
  }
}

class StudentOfMonthPickerDialog extends StatefulWidget {
  const StudentOfMonthPickerDialog({
    super.key,
    required this.pending,
    required this.repository,
  });

  final PendingStudentOfMonth pending;
  final StudentOfMonthRepository repository;

  @override
  State<StudentOfMonthPickerDialog> createState() =>
      _StudentOfMonthPickerDialogState();
}

class _StudentOfMonthPickerDialogState
    extends State<StudentOfMonthPickerDialog> {
  _Pool _pool = _Pool.top;
  int? _selectedId;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // A single top scorer is the expected answer: pre-select him so the
    // usual case is one tap. A tie leaves the choice to the teacher.
    final top = widget.pending.top;
    if (top.length == 1) _selectedId = top.first.studentId;
  }

  Future<void> _validate() async {
    final id = _selectedId;
    if (id == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.select(
        halaqaId: widget.pending.halaqaId,
        studentId: id,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = StudentOfMonthRepository.errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pending;
    final top = pending.top;
    final others = pending.others;
    final shown = _pool == _Pool.top ? top : others;
    final maxListHeight = MediaQuery.of(context).size.height * 0.4;

    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildHeader(pending),
            SizedBox(height: 12.h),
            AppText(
              'رتّبنا الطلاب حسب النقاط التي جمعوها خلال الشهر، مع خصم نقطة عن كل 100 دج من الغرامات. اختر طالباً واحداً ثم اعتمده.',
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            SizedBox(height: 16.h),
            // Ordered right-to-left on screen: the recommended pool first.
            SegmentedSelector<_Pool>(
              options: [
                SegmentOption(
                  value: _Pool.others,
                  label: 'طالب آخر (${others.length})',
                ),
                SegmentOption(
                  value: _Pool.top,
                  label: top.length > 1
                      ? 'الأعلى نقاطاً (${top.length})'
                      : 'الأعلى نقاطاً',
                ),
              ],
              selected: _pool,
              onChanged: (p) => setState(() => _pool = p),
            ),
            SizedBox(height: 12.h),
            if (_pool == _Pool.top && top.length > 1)
              Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: AppText(
                  'تعادل ${top.length} طلاب في المركز الأول، اختر واحداً منهم.',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.labelMd.copyWith(color: kAwardColor),
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxListHeight),
              child: shown.isEmpty
                  ? _buildEmptyOthers()
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => SizedBox(height: 8.h),
                      itemBuilder: (_, i) => _CandidateTile(
                        candidate: shown[i],
                        selected: shown[i].studentId == _selectedId,
                        onTap: _saving
                            ? null
                            : () => setState(() {
                                _selectedId = shown[i].studentId;
                                _error = null;
                              }),
                      ),
                    ),
            ),
            if (_error != null) ...[
              SizedBox(height: 12.h),
              AppText(
                _error!,
                textAlign: TextAlign.end,
                style: AppTextStyles.labelMd.copyWith(color: AppColors.error),
              ),
            ],
            SizedBox(height: 20.h),
            // Stacked, full width: the primary action never has to share a
            // narrow dialog with the secondary one.
            AppButton(
              label: 'اعتماد طالب الشهر',
              icon: Icons.emoji_events_outlined,
              isLoading: _saving,
              onPressed: _selectedId == null ? null : _validate,
            ),
            if (_selectedId == null) ...[
              SizedBox(height: 6.h),
              Center(
                child: AppText(
                  'اختر طالباً لتفعيل الاعتماد',
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: _saving ? null : () => Navigator.pop(context, false),
                child: AppText(
                  'لاحقاً',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(PendingStudentOfMonth pending) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                'طالب شهر ${pending.monthName}',
                textAlign: TextAlign.end,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              AppText(
                pending.halaqaName,
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Container(
          width: 48.w,
          height: 48.w,
          decoration: BoxDecoration(
            color: kAwardColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emoji_events, color: kAwardColor, size: 26.w),
        ),
      ],
    );
  }

  Widget _buildEmptyOthers() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 20.h),
      child: Column(
        children: [
          Icon(Icons.groups_outlined, color: AppColors.outline, size: 32.w),
          SizedBox(height: 8.h),
          AppText(
            'كل طلاب الحلقة في المركز الأول، اختر من تبويب «الأعلى نقاطاً».',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _CandidateTile extends StatelessWidget {
  const _CandidateTile({
    required this.candidate,
    required this.selected,
    required this.onTap,
  });

  final StudentOfMonthCandidate candidate;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final breakdown = c.finesPenalty > 0
        ? '${formatPoints(c.points)} − ${c.finesPenalty} للغرامات'
        : 'دون غرامات';

    return Semantics(
      button: true,
      selected: selected,
      label: '${c.fullName}، ${formatPoints(c.score)}',
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.08)
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.inputBorder,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? AppColors.primary : AppColors.outline,
                  size: 22.w,
                ),
                SizedBox(width: 8.w),
                // The month's score, the figure the ranking is by.
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: (c.score < 0 ? AppColors.error : AppColors.primary)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: AppText(
                    formatPoints(c.score),
                    maxLines: 1,
                    style: AppTextStyles.labelMdBold.copyWith(
                      color: c.score < 0 ? AppColors.error : AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (c.isTop) ...[
                            Icon(
                              Icons.star_rounded,
                              color: kAwardColor,
                              size: 18.w,
                            ),
                            SizedBox(width: 4.w),
                          ],
                          Flexible(
                            child: AppText(
                              c.fullName,
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodyMdBold.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      AppText(
                        breakdown,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                AvatarWidget(
                  avatarUrl: c.avatar,
                  size: AppConstants.avatarMd,
                  fallback: AppText(
                    c.fullName.isNotEmpty ? c.fullName[0] : '؟',
                    style: AppTextStyles.labelMdBold.copyWith(
                      color: AppColors.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
