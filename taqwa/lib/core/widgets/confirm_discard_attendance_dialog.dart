import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';

/// Warns the teacher that leaving the attendance screen drops chips that were
/// never saved.
///
/// Attendance is marked for a whole halaqa and saved once at the end, so an
/// accidental back-out can cost a full session of work that looks, on screen,
/// as though it were already recorded.
class ConfirmDiscardAttendanceDialog extends StatelessWidget {
  const ConfirmDiscardAttendanceDialog({super.key, required this.pendingCount});

  /// How many students are marked but unsaved.
  final int pendingCount;

  /// Shows the dialog and returns `true` only if the teacher chose to discard.
  /// A tap outside dismisses with `null`, which keeps them on the page.
  static Future<bool> show(
    BuildContext context, {
    required int pendingCount,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ConfirmDiscardAttendanceDialog(pendingCount: pendingCount),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Container(
                    width: 44.w,
                    height: 44.w,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 22.w,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      'حضور غير محفوظ',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              Text(
                'لديك $pendingCount طالب لم يتم حفظ حضورهم. الخروج الآن '
                'سيتجاهل هذه التغييرات.',
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.onSurfaceVariant,
                        side: const BorderSide(color: AppColors.outlineVariant),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        'البقاء',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: AppColors.onError,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: Text(
                        'خروج بدون حفظ',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onError,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
