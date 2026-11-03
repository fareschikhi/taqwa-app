import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_adjust.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/app_text_field.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';

/// Add or take away points by hand. Built like the fines adjust dialog, with
/// one difference: it submits itself through [onSubmit], so it can show the
/// request in flight and, when the server refuses, show why without losing
/// what was typed.
class PointsAdjustDialog extends StatefulWidget {
  const PointsAdjustDialog({super.key, required this.onSubmit});

  /// Sends the entry: a signed amount (negative for خصم) and the trimmed
  /// reason, null when blank. Throwing keeps the dialog open.
  final Future<void> Function(num signedAmount, String? reason) onSubmit;

  /// Opens the dialog; true once [onSubmit] has succeeded, false if closed.
  static Future<bool> show(
    BuildContext context, {
    required Future<void> Function(num signedAmount, String? reason) onSubmit,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => PointsAdjustDialog(onSubmit: onSubmit),
    );
    return saved ?? false;
  }

  @override
  State<PointsAdjustDialog> createState() => _PointsAdjustDialogState();
}

class _PointsAdjustDialogState extends State<PointsAdjustDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isAdding = true;
  bool _isSaving = false;
  String? _errorText;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = pointsAdjustError(
      _amountController.text,
      _reasonController.text,
    );
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    final amount = parsePointsAmount(_amountController.text)!;
    final reason = _reasonController.text.trim();

    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await widget.onSubmit(
        _isAdding ? amount : -amount,
        reason.isEmpty ? null : reason,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorText = PointsRepository.errorMessage(e);
      });
    }
  }

  Widget _directionChip(String label, bool adding) {
    final color = adding ? AppColors.primary : AppColors.error;
    return ChoiceChip(
      label: AppText(
        label,
        style: AppTextStyles.labelMd.copyWith(
          color: _isAdding == adding ? color : AppColors.onSurfaceVariant,
        ),
      ),
      selected: _isAdding == adding,
      selectedColor: color.withValues(alpha: 0.15),
      onSelected: _isSaving ? null : (_) => setState(() => _isAdding = adding),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _isAdding ? AppColors.primary : AppColors.error;

    // While the request is out, neither a tap outside nor back may close the
    // dialog: the entry may land after it is gone, and the user, told
    // nothing, adds it again.
    return PopScope(
      canPop: !_isSaving,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surface,
          title: AppText(
            'تعديل النقاط',
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8.w,
                  children: [
                    _directionChip('إضافة', true),
                    _directionChip('خصم', false),
                  ],
                ),
                SizedBox(height: 12.h),
                AppTextField(
                  label: 'العدد',
                  hint: 'مثال: 2 أو 0.5',
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  enabled: !_isSaving,
                  autofocus: true,
                ),
                SizedBox(height: 12.h),
                AppTextField(
                  label: 'السبب (اختياري)',
                  controller: _reasonController,
                  maxLines: 2,
                  maxLength: 300,
                  enabled: !_isSaving,
                ),
                if (_errorText != null) ...[
                  SizedBox(height: 8.h),
                  AppText(
                    _errorText!,
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSaving ? null : () => Navigator.pop(context, false),
              child: AppText(
                'إلغاء',
                style: AppTextStyles.button.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    )
                  : AppText(
                      'حفظ',
                      style: AppTextStyles.button.copyWith(color: accent),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
