import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../constants/app_constants.dart';
import 'package:taqwa/core/widgets/app_text.dart';

class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.onTap,
    this.textInputAction,
    this.autofocus = false,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final VoidCallback? onTap;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _obscureText = false;
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          AppText(
            widget.label!,
            style: AppTextStyles.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          SizedBox(height: 6.h),
        ],
        AnimatedContainer(
          duration: AppConstants.animFast,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppColors.inputFocusBorder.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 0),
                    ),
                  ]
                : [],
          ),
          child: TextFormField(
            controller: widget.controller,
            obscureText: _obscureText,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: _obscureText ? 1 : widget.maxLines,
            minLines: widget.minLines,
            onTap: widget.onTap,
            focusNode: _focusNode,
            textInputAction: widget.textInputAction,
            autofocus: widget.autofocus,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTextStyles.labelMd.copyWith(
                color: AppColors.inputPlaceholder,
              ),
              filled: true,
              fillColor: widget.enabled
                  ? AppColors.surfaceContainerLowest
                  : AppColors.surfaceContainerLow,
              prefixIcon: widget.prefixIcon,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: AppColors.onSurfaceVariant,
                        size: 20.w,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  : widget.suffixIcon,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.inputFocusBorder, width: 1.5),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: BorderSide(color: AppColors.inputBorder.withValues(alpha: 0.5)),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                borderSide: const BorderSide(color: AppColors.error, width: 1.5),
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 14.h,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

