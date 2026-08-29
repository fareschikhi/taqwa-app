import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Right-aligned icon + title that opens a group of related form fields.
class FormSectionHeader extends StatelessWidget {
  const FormSectionHeader({super.key, required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.primary),
        ),
        SizedBox(width: 8.w),
        Icon(icon, color: AppColors.primary, size: 22.w),
      ],
    );
  }
}

/// Label sitting above a field that renders its own box (a dropdown, the
/// user selector...). Fields built on `AppTextField` take its `label` instead.
class FormFieldLabel extends StatelessWidget {
  const FormFieldLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: AppTextStyles.labelMd.copyWith(color: AppColors.onSurfaceVariant),
  );
}
