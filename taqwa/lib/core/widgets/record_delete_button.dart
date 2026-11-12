import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// Trash button at the end of a history row (an attendance day, a
/// recitation), for staff removing an entry recorded by mistake. Shows a
/// spinner in its place while that row's delete is in flight; [onPressed] is
/// null while any delete runs, so a second one cannot start meanwhile.
class RecordDeleteButton extends StatelessWidget {
  const RecordDeleteButton({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.isDeleting = false,
  });

  /// Names the entry, so a screen reader says which row it deletes.
  final String tooltip;
  final VoidCallback? onPressed;
  final bool isDeleting;

  @override
  Widget build(BuildContext context) {
    if (isDeleting) {
      return SizedBox(
        width: 40.w,
        height: 40.w,
        child: Center(
          child: SizedBox(
            width: 18.w,
            height: 18.w,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.error,
            ),
          ),
        ),
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: BoxConstraints.tightFor(width: 40.w, height: 40.w),
      padding: EdgeInsets.zero,
      icon: Icon(Icons.delete_outline, size: 20.w),
      color: AppColors.error,
      disabledColor: AppColors.outlineVariant,
    );
  }
}
