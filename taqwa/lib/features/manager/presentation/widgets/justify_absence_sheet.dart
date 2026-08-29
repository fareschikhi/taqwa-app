import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../../features/data/models/unjustified_attendance_model.dart';
import '../../../../features/data/repositories/absence_justification_repository.dart';
import 'justification_reason_fields.dart';

/// Bottom sheet for justifying one already-identified absence.
///
/// The student, date and attendance row are fixed by [item], so unlike the
/// dashboard form there is nothing to search for or resolve: it only asks for
/// the reason and posts straight to the known attendance id.
///
/// Pops with `true` once a justification is stored.
class JustifyAbsenceSheet extends StatefulWidget {
  const JustifyAbsenceSheet({
    super.key,
    required this.managerId,
    required this.item,
  });

  final int managerId;
  final UnjustifiedAttendanceModel item;

  /// Opens the sheet and resolves to true when something was saved.
  static Future<bool> show(
    BuildContext context, {
    required int managerId,
    required UnjustifiedAttendanceModel item,
  }) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => JustifyAbsenceSheet(managerId: managerId, item: item),
    );
    return saved ?? false;
  }

  @override
  State<JustifyAbsenceSheet> createState() => _JustifyAbsenceSheetState();
}

class _JustifyAbsenceSheetState extends State<JustifyAbsenceSheet> {
  final _repo = AbsenceJustificationRepository();
  final _reasonController = TextEditingController();

  String _reasonType = JustificationReasonFields.defaultReasonType;
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: isError ? AppColors.error : AppColors.primary,
      ),
    );
  }

  Future<void> _submit() async {
    final reason = _reasonController.text;
    final reasonError = JustificationReasonFields.validate(_reasonType, reason);
    if (reasonError != null) {
      _showMessage(reasonError, isError: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _repo.createJustification({
        'studentId': widget.item.studentId,
        'attendanceId': widget.item.id,
        'managerId': widget.managerId,
        ...JustificationReasonFields.payload(_reasonType, reason),
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showMessage(
        AbsenceJustificationRepository.errorMessage(e),
        isError: true,
      );
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Lift the sheet above the keyboard while the reason is being typed.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppConstants.radiusXl),
          ),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 20.h),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.outlineVariant,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              _buildStudentHeader(),
              SizedBox(height: 20.h),
              JustificationReasonFields(
                reasonType: _reasonType,
                onReasonTypeChanged: (v) => setState(() => _reasonType = v),
                controller: _reasonController,
              ),
              SizedBox(height: 20.h),
              AppButton(
                label: 'حفظ العذر',
                variant: AppButtonVariant.gradient,
                icon: Icons.save_outlined,
                isLoading: _isSaving,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentHeader() {
    final item = widget.item;
    final statusBg =
        item.isLate ? AppColors.tertiaryContainer : AppColors.errorContainer;
    final statusFg = item.isLate
        ? AppColors.onTertiaryContainer
        : AppColors.onErrorContainer;
    final initial = item.studentName.isNotEmpty ? item.studentName[0] : '؟';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            ),
            child: Text(
              item.statusLabel,
              style: AppTextStyles.labelSm.copyWith(color: statusFg),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                item.studentName,
                style: AppTextStyles.headlineSm.copyWith(
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                item.formattedDate,
                style: AppTextStyles.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          AvatarWidget(
            avatarUrl: item.studentAvatar,
            size: 44.w,
            fallback: Text(
              initial,
              style: AppTextStyles.headlineSm.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
