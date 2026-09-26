import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../features/data/models/student_note_model.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/note_timeline.dart';
import 'app_card.dart';
import 'app_text.dart';

/// A student's teacher notes laid out as a timeline: grouped under their day,
/// each stamped with the time it was written, joined by a rail on the right.
///
/// A parent reading "حفظ جيداً اليوم" needs to know which day "today" was,
/// which a bare list of notes never told them.
class NoteTimeline extends StatelessWidget {
  const NoteTimeline({super.key, required this.notes, this.now});

  final List<StudentNoteModel> notes;

  /// Injected by tests so "اليوم" and "أمس" hold; the clock otherwise.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final days = groupNotesByDay(notes, now ?? DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var d = 0; d < days.length; d++) ...[
          if (d > 0) SizedBox(height: 8.h),
          _DayHeader(days[d].label),
          SizedBox(height: 8.h),
          for (var i = 0; i < days[d].notes.length; i++)
            _Entry(
              note: days[d].notes[i],
              // The rail runs on to the next note, on this day or the next;
              // only the very last note of the timeline ends it.
              isLast: d == days.length - 1 && i == days[d].notes.length - 1,
            ),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(999),
      ),
      child: AppText(
        label,
        style: AppTextStyles.labelMdBold.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.note, required this.isLast});
  final StudentNoteModel note;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final at = noteLocalTime(note);
    final dotSize = 12.w;

    // IntrinsicHeight so the rail's line stretches to the card's height,
    // however long the note runs.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 12.h),
              child: AppCard(
                padding: EdgeInsets.all(14.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        if (at != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppText(
                                noteTimeLabel(at),
                                style: AppTextStyles.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                              SizedBox(width: 4.w),
                              Icon(
                                Icons.schedule,
                                size: 14.w,
                                color: AppColors.onSurfaceVariant,
                              ),
                            ],
                          ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: AppText(
                            note.teacherName ?? '',
                            style: AppTextStyles.labelMdBold.copyWith(
                              color: AppColors.primary,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    AppText(
                      note.note,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(width: 10.w),
          SizedBox(
            width: dotSize,
            child: Column(
              children: [
                SizedBox(height: 16.h),
                Container(
                  width: dotSize,
                  height: dotSize,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primaryContainer,
                      width: 2,
                    ),
                  ),
                ),
                Expanded(
                  child: isLast
                      ? const SizedBox.shrink()
                      : Container(width: 2, color: AppColors.outlineVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
