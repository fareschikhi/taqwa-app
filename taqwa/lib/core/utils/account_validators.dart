import 'package:flutter/services.dart';

/// Form validators for the account screens (manager, teacher, parent,
/// student). They mirror the backend's `common/validators/account-fields.ts`,
/// so a form never lets through what the API will reject — and the messages
/// match what the server would say.
class AccountValidators {
  AccountValidators._();

  /// A phone in its stored form: an Algerian number in local form
  /// ("0551234567") or any other country's in international form
  /// ("+33612345678"). Loose on length, since numbering plans differ, but
  /// within E.164's 15 digits.
  static final _storedPhone = RegExp(r'^(?:0\d{6,14}|\+[1-9]\d{6,14})$');

  // Deliberately loose: one @, no spaces, a dot in the domain. The server's
  // IsEmail is the final word; this only catches obvious typos early.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  /// The number box beside the country code: up to E.164's 15 digits, plus a
  /// leading + for pasting a full number from a country not in the list.
  static const phoneLength = 16;
  static final phoneInputFormatters = [
    FilteringTextInputFormatter.allow(RegExp(r'[\d+]')),
  ];

  static const phoneError = 'رقم الهاتف غير صالح';

  /// Same folding the server applies before storing: drops spacing and
  /// punctuation, turns 00 into +, and turns +213 into the local 0 prefix
  /// (dropping a trunk 0 typed after the code).
  static String normalizePhone(String value) {
    final compact = value
        .replaceAll(RegExp(r'[\s\-.()]'), '')
        .replaceFirst(RegExp(r'^00'), '+');
    final algerian = RegExp(r'^\+2130?(\d+)$').firstMatch(compact);
    return algerian != null ? '0${algerian.group(1)}' : compact;
  }

  /// The stored form of [number] typed beside [dialCode] ("+213"), or '' when
  /// nothing was typed. A number starting with + already carries its own code.
  static String composePhone(String dialCode, String number) {
    final value = number.trim();
    if (value.isEmpty) return '';
    return normalizePhone(value.startsWith('+') ? value : '$dialCode$value');
  }

  static String? fullName(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'الاسم مطلوب';
    if (value.length > 100) return 'الاسم طويل جداً';
    return null;
  }

  static String? phone(String? v, {bool required = false}) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return required ? 'رقم الهاتف مطلوب' : null;
    return _storedPhone.hasMatch(normalizePhone(value)) ? null : phoneError;
  }

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return null;
    return _email.hasMatch(value) ? null : 'البريد الإلكتروني غير صالح';
  }

  /// [optional] is for edit forms, where a blank field keeps the current
  /// password; anything typed is still length-checked.
  static String? password(String? v, {bool optional = false}) {
    final value = v?.trim() ?? '';
    if (optional && value.isEmpty) return null;
    return value.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null;
  }
}
