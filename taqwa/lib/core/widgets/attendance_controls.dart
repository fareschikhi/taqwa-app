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
/// The memorization button opens the recitation sheet and the "لم يحفظ"
/// toggle charges a fine, but they answer the same question — did he recite
/// today? — so they are built from one shell and read as a pair.
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

/// Picks one of the three attendance marks, tinted to whichever is chosen.
///
/// Every student's row opens on [AttendanceStatus.present], so this never
/// shows [AttendanceStatus.unset]: the sheet records exceptions, and a mark
/// nobody changed still means the student was there.
class AttendanceDropdown extends StatelessWidget {
  const AttendanceDropdown({
    super.key,
    required this.status,
    required this.onChanged,
    this.lateFeeLabel,
    this.enabled = true,
  });

  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  /// What lateness costs in this student's halaqa, already formatted, or null
  /// when it is free. Shown against the late entry so the teacher reads the
  /// price while choosing rather than after.
  final String? lateFeeLabel;

  final bool enabled;

  static const _options = [
    (AttendanceStatus.present, 'حاضر'),
    (AttendanceStatus.late, 'متأخر'),
    (AttendanceStatus.absent, 'غائب'),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = attendanceColors(status);
    final ink = enabled ? colors.ink : AppColors.outlineVariant;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      decoration: BoxDecoration(
        color: enabled ? colors.fill : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(
          color: enabled ? colors.fill : AppColors.outlineVariant,
          width: 1.5,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AttendanceStatus>(
          value: status,
          isExpanded: true,
          // Not dense: the button sizes itself to the tallest entry it could
          // show, and the late one runs to two lines when the halaqa charges
          // for it. A dense button caps that height and clips the fee.
          // Null rather than the 48px default: the late entry runs to two
          // lines when the halaqa charges for it, and a fixed height would
          // clip the fee right off the menu.
          itemHeight: null,
          padding: EdgeInsets.symmetric(vertical: 10.h),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          icon: Icon(Icons.arrow_drop_down, color: ink),
          dropdownColor: AppColors.surfaceContainerLowest,
          onChanged: enabled
              ? (value) {
                  if (value != null) onChanged(value);
                }
              : null,
          // The closed button paints on the status fill, but the open menu
          // paints on the surface, so the same entry needs a different ink in
          // each place. selectedItemBuilder is what draws the closed state.
          selectedItemBuilder: (context) => [
            for (final (itemStatus, label) in _options)
              _Entry(
                label: label,
                feeLabel: itemStatus == AttendanceStatus.late
                    ? lateFeeLabel
                    : null,
                color: ink,
              ),
          ],
          items: [
            for (final (itemStatus, label) in _options)
              DropdownMenuItem(
                value: itemStatus,
                child: _Entry(
                  label: label,
                  feeLabel: itemStatus == AttendanceStatus.late
                      ? lateFeeLabel
                      : null,
                  color: AppColors.onSurface,
                  dotColor: attendanceColors(itemStatus).fill,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One line of the dropdown: the mark, and what it costs if it costs anything.
class _Entry extends StatelessWidget {
  const _Entry({
    required this.label,
    required this.color,
    this.feeLabel,
    this.dotColor,
  });

  final String label;
  final Color color;
  final String? feeLabel;

  /// Shown only in the open menu, where every entry sits on the same neutral
  /// surface and the colour is the only thing telling them apart.
  final Color? dotColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (dotColor != null) ...[
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
        ],
        // The fee goes under the label rather than beside it: the menu is laid
        // out to the button's width, and the two side by side do not fit it.
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.labelMdBold.copyWith(color: color),
              ),
              if (feeLabel != null)
                AppText(
                  feeLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelSm.copyWith(color: color),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
