import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

enum AttendanceStatus { present, absent, late, unset }

class AttendanceChip extends StatelessWidget {
  const AttendanceChip({
    super.key,
    required this.label,
    required this.status,
    required this.myStatus,
    required this.onTap,
  });

  final String label;
  final AttendanceStatus status;
  final AttendanceStatus myStatus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = status == myStatus;

    Color bgColor;
    Color textColor;
    Color borderColor;
    IconData? leadIcon;

    switch (myStatus) {
      case AttendanceStatus.present:
        bgColor = isSelected ? AppColors.present : AppColors.surfaceContainerLowest;
        textColor = isSelected ? AppColors.onPrimary : AppColors.onSurfaceVariant;
        borderColor = isSelected ? AppColors.present : AppColors.outlineVariant;
        leadIcon = isSelected ? Icons.check_circle : null;
      case AttendanceStatus.absent:
        bgColor = isSelected ? AppColors.absent : AppColors.surfaceContainerLowest;
        textColor = isSelected ? AppColors.onError : AppColors.onSurfaceVariant;
        borderColor = isSelected ? AppColors.absent : AppColors.outlineVariant;
        leadIcon = isSelected ? Icons.cancel : null;
      case AttendanceStatus.late:
        bgColor = isSelected ? AppColors.late : AppColors.surfaceContainerLowest;
        textColor = isSelected ? Colors.white : AppColors.onSurfaceVariant;
        borderColor = isSelected ? AppColors.late : AppColors.outlineVariant;
        leadIcon = isSelected ? Icons.schedule : null;
      case AttendanceStatus.unset:
        bgColor = AppColors.surfaceContainerLowest;
        textColor = AppColors.onSurfaceVariant;
        borderColor = AppColors.outlineVariant;
        leadIcon = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppConstants.animFast,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leadIcon != null) ...[
              Icon(leadIcon, color: textColor, size: 16.w),
              SizedBox(width: 4.w),
            ],
            AppText(
              label,
              style: AppTextStyles.labelMdBold.copyWith(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
