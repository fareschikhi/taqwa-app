import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/constants/app_constants.dart';

/// Shared row of card actions: an optional active/inactive toggle, a delete
/// button, and an outlined edit button. Used across the admin management
/// list cards (managers, parents, students, teachers, halaqas).
class CardActionRow extends StatelessWidget {
  const CardActionRow({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.isActive,
    this.onToggleActive,
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// Null when the entity has no active/inactive concept (e.g. halaqas).
  /// In that case the toggle is not rendered at all.
  final bool? isActive;
  final VoidCallback? onToggleActive;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (isActive != null) ...[
          // Toggle status btn
          GestureDetector(
            onTap: onToggleActive,
            child: Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                color: isActive!
                    ? AppColors.errorContainer
                    : AppColors.primaryContainer,
              ),
              child: Icon(
                isActive! ? Icons.block : Icons.check_circle_outline,
                size: 18.w,
                color: isActive!
                    ? AppColors.error
                    : AppColors.onPrimaryContainer,
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
                  Text(
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
}
