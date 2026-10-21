import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/account_validators.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/datasources/user_remote_datasource.dart';
import 'package:taqwa/features/data/models/user_model.dart';
import '../pages/profile_page.dart' show roleLabelFor;

enum ContactField { phone, email }

/// Sits under a phone or email field and names the accounts already holding
/// that value. Sharing is allowed — one person can be a teacher and an adult
/// student — so this only warns; it never blocks the form.
///
/// Looks up after a pause in typing, and only once the value is well formed,
/// so half-typed numbers never hit the server.
class ContactOwnersHint extends StatefulWidget {
  const ContactOwnersHint({
    super.key,
    required this.controller,
    required this.field,
    this.excludeUserId,
  });

  final TextEditingController controller;
  final ContactField field;

  /// The account being edited, so its own value does not warn about itself.
  final int? excludeUserId;

  @override
  State<ContactOwnersHint> createState() => _ContactOwnersHintState();
}

class _ContactOwnersHintState extends State<ContactOwnersHint> {
  final _users = UserRemoteDatasource();
  Timer? _debounce;
  String _lookedUp = '';
  List<({String fullName, UserRole role})> _owners = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _onChanged();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  String get _value {
    final raw = widget.controller.text.trim();
    final isPhone = widget.field == ContactField.phone;
    final invalid = isPhone
        ? AccountValidators.phone(raw) != null
        : AccountValidators.email(raw) != null;
    if (raw.isEmpty || invalid) return '';
    return isPhone ? AccountValidators.normalizePhone(raw) : raw;
  }

  void _onChanged() {
    final value = _value;
    if (value == _lookedUp) return;
    _debounce?.cancel();
    if (value.isEmpty) {
      _lookedUp = '';
      if (_owners.isNotEmpty) setState(() => _owners = const []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () => _lookUp(value));
  }

  Future<void> _lookUp(String value) async {
    _lookedUp = value;
    try {
      final owners = await _users.contactOwners(
        phone: widget.field == ContactField.phone ? value : null,
        email: widget.field == ContactField.email ? value : null,
        excludeUserId: widget.excludeUserId,
      );
      // A newer value may have been typed while this one was in flight.
      if (!mounted || value != _lookedUp) return;
      setState(() => _owners = owners);
    } catch (_) {
      // The hint is a courtesy: a failed lookup just shows nothing.
      if (mounted && value == _lookedUp) setState(() => _owners = const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_owners.isEmpty) return const SizedBox.shrink();
    final what =
        widget.field == ContactField.phone ? 'رقم الهاتف' : 'البريد الإلكتروني';
    final who = _owners
        .map((o) => '${o.fullName} (${roleLabelFor(o.role)})')
        .join('، ');
    return Padding(
      padding: EdgeInsets.only(top: 6.h, right: 4.w, left: 4.w),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16.sp, color: AppColors.warning),
          SizedBox(width: 6.w),
          Expanded(
            child: AppText(
              '$what مستخدم من قبل: $who',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}
