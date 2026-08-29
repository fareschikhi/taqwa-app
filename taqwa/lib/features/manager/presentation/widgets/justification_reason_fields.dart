import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/app_text_field.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// The reason type dropdown plus its detail text field, shared by every place
/// a justification can be written.
///
/// The payload rules live here as statics so the two entry points can't drift
/// apart on how a reason maps onto reasonType/customReason/notes.
class JustificationReasonFields extends StatelessWidget {
  const JustificationReasonFields({
    super.key,
    required this.reasonType,
    required this.onReasonTypeChanged,
    required this.controller,
  });

  final String reasonType;
  final ValueChanged<String> onReasonTypeChanged;
  final TextEditingController controller;

  /// Options offered to the manager, keyed by the API's
  /// JustificationReasonType enum.
  static const reasonTypes = <String, String>{
    'ILLNESS': 'مرض',
    'OCCASION': 'مناسبة (عائلية، اجتماعية)',
    'OTHER': 'أخرى',
  };

  static const defaultReasonType = 'ILLNESS';

  /// Returns an Arabic error message when the pair is unusable, else null.
  static String? validate(String reasonType, String text) {
    if (reasonType == 'OTHER' && text.trim().isEmpty) {
      return 'يرجى كتابة سبب الغياب';
    }
    return null;
  }

  /// The reason portion of a create-justification payload.
  ///
  /// For OTHER the text becomes the chip label (customReason); otherwise it is
  /// kept as the card body (notes), so the text is never rendered twice.
  static Map<String, dynamic> payload(String reasonType, String text) {
    final trimmed = text.trim();
    return {
      'reasonType': reasonType,
      if (reasonType == 'OTHER')
        'customReason': trimmed
      else if (trimmed.isNotEmpty)
        'notes': trimmed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isOther = reasonType == 'OTHER';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          'نوع العذر *',
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            border: Border.all(color: AppColors.inputBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: reasonType,
              isExpanded: true,
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              icon: Icon(
                Icons.expand_more,
                color: AppColors.onSurfaceVariant,
                size: 22.w,
              ),
              style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
              onChanged: (v) {
                if (v != null) onReasonTypeChanged(v);
              },
              items: reasonTypes.entries
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: AppText(e.value, textAlign: TextAlign.right),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        AppTextField(
          label: isOther ? 'سبب الغياب *' : 'ملاحظات إضافية',
          hint: isOther
              ? 'يرجى توضيح العذر هنا...'
              : 'أضف أي تفاصيل أخرى (اختياري)',
          controller: controller,
          maxLines: 3,
          minLines: 2,
        ),
      ],
    );
  }
}
