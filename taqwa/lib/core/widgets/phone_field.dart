import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../constants/app_constants.dart';
import '../constants/country_dial_codes.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/account_validators.dart';
import 'app_text.dart';
import 'app_text_field.dart';

/// A phone input split into a country code (Algeria preselected) and the
/// number beside it.
///
/// [controller] holds the phone in its stored form ("0551234567" for Algeria,
/// "+33612345678" elsewhere), so forms keep reading and prefilling it as
/// before. It is only rewritten when the user edits this field, so an old
/// number that the split can't represent is sent back untouched.
class PhoneField extends StatefulWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'رقم الهاتف',
    this.validator,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;

  /// Called with the stored form, not with what is in the number box.
  final FormFieldValidator<String>? validator;
  final bool enabled;

  @override
  State<PhoneField> createState() => _PhoneFieldState();
}

class _PhoneFieldState extends State<PhoneField> {
  final _number = TextEditingController();
  CountryDialCode _country = kAlgeria;

  /// The last value this field wrote to (or read from) [PhoneField.controller],
  /// to tell its own writes from a form prefilling it.
  String _synced = '';

  @override
  void initState() {
    super.initState();
    _load(widget.controller.text);
    widget.controller.addListener(_onOuterChanged);
  }

  @override
  void didUpdateWidget(covariant PhoneField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onOuterChanged);
      widget.controller.addListener(_onOuterChanged);
      _load(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onOuterChanged);
    _number.dispose();
    super.dispose();
  }

  void _load(String stored) {
    final value = stored.trim();
    _synced = stored;
    final country = value.startsWith('+') ? countryForPhone(value) : null;
    if (country != null) {
      _country = country;
      _number.text = value.substring(country.dialCode.length);
    } else {
      // Local Algerian form drops its trunk 0 beside +213. Anything else
      // (an unlisted +code, an old short number) is shown as it is.
      _country = kAlgeria;
      _number.text = value.startsWith('0') ? value.substring(1) : value;
    }
  }

  void _onOuterChanged() {
    if (widget.controller.text == _synced) return;
    setState(() => _load(widget.controller.text));
  }

  void _write() {
    _synced = AccountValidators.composePhone(_country.dialCode, _number.text);
    widget.controller.text = _synced;
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<CountryDialCode>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
      ),
      builder: (ctx) => _CountrySheet(selected: _country),
    );
    if (picked == null || !mounted) return;
    setState(() => _country = picked);
    _write();
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label,
      hint: 'XXXXXXXXX',
      controller: _number,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      maxLength: AccountValidators.phoneLength,
      inputFormatters: AccountValidators.phoneInputFormatters,
      // Numbers read left to right, so the number hugs its code on the left.
      textAlign: TextAlign.left,
      onChanged: (_) => _write(),
      validator: widget.validator == null
          ? null
          : (_) => widget.validator!(widget.controller.text),
      // The app runs under an LTR Directionality (main.dart), so prefix is the
      // left edge: the code reads first, as in "+213 551234567".
      prefixIcon: _CountryButton(
        country: _country,
        onTap: widget.enabled ? _pickCountry : null,
      ),
      suffixIcon: const Icon(
        Icons.phone_outlined,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}

/// The code at the number's left edge; opens the country list.
class _CountryButton extends StatelessWidget {
  const _CountryButton({required this.country, required this.onTap});

  final CountryDialCode country;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        onTap == null ? AppColors.onSurfaceVariant : AppColors.onSurface;
    return Semantics(
      button: true,
      label: 'رمز الدولة ${country.name} ${country.dialCode}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Padding(
          // Sits at the field's left edge; the divider faces the number.
          padding: EdgeInsets.only(left: 12.w, right: 4.w),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: TextDirection.ltr,
            children: [
              AppText(country.flag, style: AppTextStyles.bodyMd),
              SizedBox(width: 6.w),
              AppText(
                country.dialCode,
                textDirection: TextDirection.ltr,
                style: AppTextStyles.bodyMd.copyWith(color: color),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_drop_down,
                  size: 20.w,
                  color: AppColors.onSurfaceVariant,
                ),
              SizedBox(width: 8.w),
              Container(
                width: 1,
                height: 24.h,
                color: AppColors.inputBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountrySheet extends StatelessWidget {
  const _CountrySheet({required this.selected});

  final CountryDialCode selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 4.h),
              child: AppText('اختر رمز الدولة', style: AppTextStyles.labelMdBold),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: AppText(
                'لدولة غير موجودة، اكتب الرقم كاملاً مبتدئاً بـ +',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
            SizedBox(height: 8.h),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: kCountryDialCodes.length,
                itemBuilder: (ctx, i) {
                  final c = kCountryDialCodes[i];
                  final isSelected = identical(c, selected);
                  return ListTile(
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    leading: AppText(c.flag, style: AppTextStyles.bodyLg),
                    title: AppText(c.name, style: AppTextStyles.bodyMd),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(
                          c.dialCode,
                          textDirection: TextDirection.ltr,
                          style: AppTextStyles.bodyMd.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.onSurfaceVariant,
                          ),
                        ),
                        if (isSelected) ...[
                          SizedBox(width: 8.w),
                          Icon(Icons.check, size: 18.w, color: AppColors.primary),
                        ],
                      ],
                    ),
                    onTap: () => Navigator.pop(ctx, c),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
