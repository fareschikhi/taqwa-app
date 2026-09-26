/// Form validators for the account screens (manager, teacher, parent,
/// student). They mirror the backend's `common/validators/account-fields.ts`,
/// so a form never lets through what the API will reject — and the messages
/// match what the server would say.
class AccountValidators {
  AccountValidators._();

  /// An Algerian mobile in its stored form: 05/06/07 followed by 8 digits.
  static final _algerianMobile = RegExp(r'^0[567]\d{8}$');

  // Deliberately loose: one @, no spaces, a dot in the domain. The server's
  // IsEmail is the final word; this only catches obvious typos early.
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static const phoneError =
      'رقم الهاتف غير صالح: 10 أرقام تبدأ بـ 05 أو 06 أو 07';

  /// Same folding the server applies before storing: drops spacing and
  /// punctuation, and turns +213/00213 into the local 0 prefix.
  static String normalizePhone(String value) {
    final compact = value.replaceAll(RegExp(r'[\s\-.()]'), '');
    final international = RegExp(r'^(?:\+|00)213(\d{9})$').firstMatch(compact);
    return international != null ? '0${international.group(1)}' : compact;
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
    return _algerianMobile.hasMatch(normalizePhone(value)) ? null : phoneError;
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
