import 'dart:math' show pi;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

enum AttendanceStatus { present, absent, late, unset }

/// One of the two recitation controls under a student's name: an icon with
/// its label beneath it.
///
/// Built as one shell so recitation controls placed side by side read as a
/// set: same icon size, label position and badge behaviour.
class RecitationButton extends StatelessWidget {
  const RecitationButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subLabel,
    this.selected = false,
    this.highlighted = false,
    this.selectedInk = AppColors.onError,
    this.strikethrough = false,
    this.showBadge = false,
    this.enabled = true,
  });

  final IconData icon;

  final String label;

  /// What this control costs, on a line of its own under [label].
  ///
  /// Slash-joining it onto the label reads well but needs 205w, and the two
  /// buttons split a 326w row evenly — so the fee gets its own line instead
  /// of the label shrinking to fit a money value.
  final String? subLabel;

  /// The control's own colour: the fill once it is on, the ink until then.
  final Color color;

  /// Filled, because the teacher has turned this on.
  final bool selected;

  /// Tinted rather than filled, because something is already on file for it.
  /// This is how the memorization button shows it holds today's recitation.
  final bool highlighted;

  /// The label colour against [color] when filled.
  final Color selectedInk;

  /// Strikes the icon through, for the control that means "did not".
  final bool strikethrough;

  /// A dot on the icon's corner, for the button that already has something
  /// recorded behind it.
  final bool showBadge;

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isOn = selected && enabled;
    final Color ink;
    final Color background;
    final Color border;

    if (!enabled) {
      ink = AppColors.outlineVariant;
      background = AppColors.surfaceContainerLow;
      border = AppColors.outlineVariant.withValues(alpha: 0.5);
    } else if (isOn) {
      ink = selectedInk;
      background = color;
      border = color;
    } else if (highlighted) {
      ink = color;
      background = color.withValues(alpha: 0.08);
      border = color;
    } else {
      ink = color;
      background = AppColors.surfaceContainerLow;
      border = AppColors.inputBorder;
    }

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(
            color: border,
            width: highlighted && !isOn ? 1.2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(ink),
            SizedBox(height: 2.h),
            AppText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMdBold.copyWith(color: ink),
            ),
            if (subLabel != null)
              AppText(
                subLabel!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelSm.copyWith(color: ink),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color ink) {
    final glyph = Icon(icon, size: 22, color: ink);
    if (!strikethrough && !showBadge) return glyph;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        glyph,
        // The same book glyph struck through, so "did not recite" reads as
        // the opposite of the button beside it rather than as a new idea.
        if (strikethrough)
          Transform.rotate(
            angle: -pi / 4,
            child: Container(width: 26.w, height: 2, color: ink),
          ),
        if (showBadge)
          Positioned(
            top: -2,
            right: -2,
            child: Container(
              width: 8.w,
              height: 8.w,
              decoration: BoxDecoration(
                color: AppColors.present,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceContainerLowest,
                  width: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The colour a mark is shown in, wherever it is shown.
///
/// The late amber is light enough that white on it sits near 2:1, so it takes
/// dark ink where the other two take white.
({Color fill, Color ink}) attendanceColors(AttendanceStatus status) =>
    switch (status) {
      AttendanceStatus.present => (
        fill: AppColors.present,
        ink: AppColors.onPrimary,
      ),
      AttendanceStatus.absent => (
        fill: AppColors.absent,
        ink: AppColors.onError,
      ),
      AttendanceStatus.late => (fill: AppColors.late, ink: AppColors.onSurface),
      AttendanceStatus.unset => (
        fill: AppColors.surfaceContainerLowest,
        ink: AppColors.onSurfaceVariant,
      ),
    };

/// The three attendance marks side by side, so a mark costs a single tap.
///
/// Every student's row opens on [AttendanceStatus.present], so this never
/// shows [AttendanceStatus.unset]: the sheet records exceptions, and a mark
/// nobody changed still means the student was there. The app lays rows out
/// left to right, so present is listed last to sit first for an Arabic reader.
class AttendanceSelector extends StatelessWidget {
  const AttendanceSelector({
    super.key,
    required this.status,
    required this.onChanged,
    this.lateFeeLabel,
    this.enabled = true,
  });

  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  /// What lateness costs in this student's halaqa, already formatted, or null
  /// when it is free. Printed under the late segment so the teacher reads the
  /// price before tapping rather than after.
  final String? lateFeeLabel;

  final bool enabled;

  static const _options = [
    (AttendanceStatus.absent, 'غائب'),
    (AttendanceStatus.late, 'متأخر'),
    (AttendanceStatus.present, 'حاضر'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.inputBorder),
      ),
      // IntrinsicHeight so the late segment's fee line sets one height for
      // all three, inside a list that hands down no height of its own.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (itemStatus, label) in _options)
              Expanded(
                child: _Segment(
                  label: label,
                  feeLabel: itemStatus == AttendanceStatus.late
                      ? lateFeeLabel
                      : null,
                  color: attendanceColors(itemStatus),
                  selected: status == itemStatus,
                  enabled: enabled,
                  onTap: () => onChanged(itemStatus),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One mark of [AttendanceSelector]: filled in its own colour once chosen,
/// a coloured dot beside the label until then.
class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.feeLabel,
  });

  final String label;
  final String? feeLabel;
  final ({Color fill, Color ink}) color;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color ink;
    if (!enabled) {
      ink = AppColors.outlineVariant;
    } else if (selected) {
      ink = color.ink;
    } else {
      ink = AppColors.onSurfaceVariant;
    }

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: enabled && !selected ? onTap : null,
          borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            constraints: BoxConstraints(minHeight: 40.h),
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 6.h),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? (enabled ? color.fill : AppColors.surfaceContainerHigh)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.radiusDefault),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: AppText(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMdBold.copyWith(color: ink),
                      ),
                    ),
                    if (!selected) ...[
                      SizedBox(width: 6.w),
                      Container(
                        width: 8.w,
                        height: 8.w,
                        decoration: BoxDecoration(
                          color: enabled
                              ? color.fill
                              : AppColors.outlineVariant,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
                if (feeLabel != null)
                  AppText(
                    feeLabel!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.labelSm.copyWith(color: ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
