/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits, and the Arabic decimal
/// separator (٫), mapped to what [num.tryParse] reads.
final _digitMap = <String, String>{
  for (var i = 0; i < 10; i++) String.fromCharCode(0x0660 + i): '$i',
  for (var i = 0; i < 10; i++) String.fromCharCode(0x06F0 + i): '$i',
  '٫': '.',
  ',': '.',
};

/// What a teacher typed in the amount field, as a number, or null when it is
/// not one. A phone keyboard set to Arabic or French gives Arabic digits or a
/// decimal comma; both are read, not refused.
num? parsePointsAmount(String text) {
  final normalized = text.trim().split('').map((c) => _digitMap[c] ?? c).join();
  return num.tryParse(normalized);
}

/// Why this adjustment cannot be sent, or null when it can. The server holds
/// the same rules and has the last word; this only says it before the round
/// trip. The sign is not typed: the add/subtract toggle carries it.
String? pointsAdjustError(String amountText, String reason) {
  final amount = parsePointsAmount(amountText);
  if (amount == null || amount <= 0) return 'أدخل عدداً أكبر من صفر';
  if (amount > 1000) return 'أقصى قيمة هي 1000';
  if (double.parse(amount.toStringAsFixed(2)) != amount) {
    return 'رقمان بعد الفاصلة على الأكثر';
  }
  if (reason.trim().length > 300) return 'السبب طويل جداً (300 حرف على الأكثر)';
  return null;
}
