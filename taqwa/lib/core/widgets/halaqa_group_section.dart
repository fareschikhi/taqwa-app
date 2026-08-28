import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';

/// Arabic reads a count differently at one, two, and past ten, so the header
/// label is built rather than interpolated.
String studentCountLabel(int count) {
  if (count == 1) return 'طالب واحد';
  if (count == 2) return 'طالبان';
  if (count <= 10) return '$count طلاب';
  return '$count طالباً';
}

/// A foldable band of students that share one halaqa. The caller owns the
/// expanded state so a page can remember which circles the user closed.
class HalaqaGroupSection extends StatelessWidget {
  const HalaqaGroupSection({
    super.key,
    required this.title,
    required this.count,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
    this.isUnassigned = false,
  });

  final String title;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  /// The bucket of students in no halaqa reads as a gap to close rather than
  /// a circle, so it is tinted apart from the rest.
  final bool isUnassigned;

  @override
  Widget build(BuildContext context) {
    final accent = isUnassigned ? AppColors.outline : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onToggle,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              border: Border(right: BorderSide(color: accent, width: 3.w)),
            ),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20.w,
                  color: AppColors.onSurfaceVariant,
                ),
                const Spacer(),
                Text(
                  studentCountLabel(count),
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                SizedBox(width: 8.w),
                Flexible(
                  child: Text(
                    title,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMdBold.copyWith(color: accent),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          SizedBox(height: 12.h),
          ...children,
        ],
      ],
    );
  }
}
