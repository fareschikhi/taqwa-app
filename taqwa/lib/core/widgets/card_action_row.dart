import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/utils/telegram.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Shared row of card actions: an optional Telegram button, an optional
/// active/inactive toggle, a delete button, and an outlined edit button. Used across the admin management
/// list cards (managers, parents, students, teachers, halaqas).
class CardActionRow extends StatelessWidget {
  const CardActionRow({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.isActive,
    this.onToggleActive,
    this.onTelegram,
    this.compact = false,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Null when the entity has no active/inactive concept (e.g. halaqas).
  /// In that case the toggle is not rendered at all.
  final bool? isActive;
  final VoidCallback? onToggleActive;

  /// Null hides the Telegram button, e.g. when there is no usable number.
  final VoidCallback? onTelegram;

  /// For a narrow grid card: the buttons share the width equally and edit
  /// drops its label, which would not fit beside three icon buttons.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return Row(
      children: [
        if (onTelegram != null) ...[
          Tooltip(
            message: 'تيليجرام',
            child: GestureDetector(
              onTap: onTelegram,
              child: Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  color: kTelegramBlue,
                ),
                child: Icon(Icons.telegram, size: 18.w, color: Colors.white),
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
        if (isActive != null) ...[
          // Toggle status btn: shows the current status (green = active,
          // red = inactive); tapping opens the confirm dialog to flip it.
          GestureDetector(
            onTap: onToggleActive,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                color: isActive!
                    ? AppColors.primaryContainer
                    : AppColors.errorContainer,
              ),
              child: Icon(
                isActive! ? Icons.check_circle_outline : Icons.block,
                size: 18.w,
                color: isActive!
                    ? AppColors.onPrimaryContainer
                    : AppColors.error,
              ),
            ),
          ),
          SizedBox(width: 8.w),
        ],
        // Delete btn
        GestureDetector(
          onTap: onDelete,
          child: Container(
            width: 38.w,
            height: 38.w,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppConstants.radiusMd,
              ),
              color: AppColors.errorContainer,
            ),
            child: Icon(
              Icons.delete_outline,
              size: 18.w,
              color: AppColors.error,
            ),
          ),
        ),
        SizedBox(width: 8.w),
        // Edit button
        Expanded(
          child: GestureDetector(
            onTap: onEdit,
            child: Container(
              height: 38.h,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.outlineVariant),
                borderRadius: BorderRadius.circular(
                  AppConstants.radiusMd,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 16.w,
                    color: AppColors.secondary,
                  ),
                  SizedBox(width: 4.w),
                  AppText(
                    'تعديل',
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompact() {
    final buttons = <Widget>[
      if (onTelegram != null)
        _iconButton(
          tooltip: 'تيليجرام',
          icon: Icons.telegram,
          background: kTelegramBlue,
          color: Colors.white,
          onTap: onTelegram,
        ),
      if (isActive != null)
        _iconButton(
          tooltip: isActive! ? 'نشط' : 'غير نشط',
          icon: isActive! ? Icons.check_circle_outline : Icons.block,
          background: isActive!
              ? AppColors.primaryContainer
              : AppColors.errorContainer,
          color: isActive! ? AppColors.onPrimaryContainer : AppColors.error,
          onTap: onToggleActive,
        ),
      _iconButton(
        tooltip: 'حذف',
        icon: Icons.delete_outline,
        background: AppColors.errorContainer,
        color: AppColors.error,
        onTap: onDelete,
      ),
      _iconButton(
        tooltip: 'تعديل',
        icon: Icons.edit_outlined,
        color: AppColors.secondary,
        border: AppColors.outlineVariant,
        onTap: onEdit,
      ),
    ];
    return Row(
      children: [
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) SizedBox(width: 6.w),
          Expanded(child: buttons[i]),
        ],
      ],
    );
  }

  Widget _iconButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
    Color? background,
    Color? border,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 38.w,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            color: background,
            border: border == null ? null : Border.all(color: border),
          ),
          child: Icon(icon, size: 18.w, color: color),
        ),
      ),
    );
  }
}
