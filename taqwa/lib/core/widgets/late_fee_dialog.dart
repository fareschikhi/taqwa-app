import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import '../utils/fine_balance.dart';
import 'app_text_field.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// The most a teacher can type for one late arrival. Matches the server's
/// own ceiling, so a value that passes here is never refused there.
const int maxLateFee = 100000;

/// Why [text] is not a usable late fee, or null when it is.
String? lateFeeError(String text) {
  final value = int.tryParse(text.trim());
  if (value == null) return 'أدخل مبلغاً صحيحاً';
  if (value < 0) return 'لا يمكن أن يكون المبلغ سالباً';
  if (value > maxLateFee) return 'المبلغ كبير جداً';
  return null;
}

/// Asks the teacher how much this late arrival costs, instead of charging the
/// halaqa's rate on its own. Lateness varies — five minutes is not an hour —
/// so the amount is hers to decide each time; the halaqa's rate is only the
/// starting value.
///
/// Returns the chosen amount (0 waives it), or null when she backed out, in
/// which case the student's mark must not change.
class LateFeeDialog extends StatefulWidget {
  const LateFeeDialog({
    super.key,
    required this.title,
    required this.defaultFee,
  });

  /// Names who is being marked: one student, or "N students" for the header.
  final String title;

  /// Prefilled amount — the halaqa's usual late fee.
  final int defaultFee;

  static Future<int?> show(
    BuildContext context, {
    required String title,
    required int defaultFee,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => LateFeeDialog(title: title, defaultFee: defaultFee),
    );
  }

  @override
  State<LateFeeDialog> createState() => _LateFeeDialogState();
}

class _LateFeeDialogState extends State<LateFeeDialog> {
  late final _controller = TextEditingController(
    text: widget.defaultFee.toString(),
  );
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = lateFeeError(_controller.text);
    if (error != null) {
      setState(() => _errorText = error);
      return;
    }
    Navigator.pop(context, int.parse(_controller.text.trim()));
  }

  /// One-tap amounts, so the common cases need no typing. The halaqa's rate
  /// leads; 0 is always there for "late, but excused".
  List<int> get _presets {
    final base = widget.defaultFee;
    return {0, if (base > 0) base, if (base > 0) base * 2}.toList()..sort();
  }

  Widget _presetChip(int amount) {
    final selected = _controller.text.trim() == amount.toString();
    return ChoiceChip(
      label: AppText(
        amount == 0 ? 'بدون غرامة' : formatFine(amount),
        style: AppTextStyles.labelMd.copyWith(
          color: selected ? AppColors.onSurface : AppColors.onSurfaceVariant,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.late.withValues(alpha: 0.25),
      onSelected: (_) => setState(() {
        _controller.text = amount.toString();
        _errorText = null;
      }),
    );
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
                      color: AppColors.late.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.schedule_rounded,
                      color: AppColors.onSurface,
                      size: 22.w,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: AppText(
                      'غرامة التأخر',
                      style: AppTextStyles.headlineSm.copyWith(
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8.h),
              AppText(
                widget.title,
                style: AppTextStyles.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
              SizedBox(height: 16.h),
              Directionality(
                textDirection: TextDirection.rtl,
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [for (final p in _presets) _presetChip(p)],
                ),
              ),
              SizedBox(height: 12.h),
              AppTextField(
                label: 'المبلغ (دج)',
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() => _errorText = null),
                onSubmitted: (_) => _submit(),
              ),
              if (_errorText != null) ...[
                SizedBox(height: 8.h),
                AppText(
                  _errorText!,
                  style: AppTextStyles.labelMd.copyWith(color: AppColors.error),
                  textAlign: TextAlign.end,
                ),
              ],
              SizedBox(height: 24.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
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
                      child: AppText(
                        'إلغاء',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusMd,
                          ),
                        ),
                      ),
                      child: AppText(
                        'تسجيل التأخر',
                        style: AppTextStyles.button.copyWith(
                          color: AppColors.onPrimary,
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
