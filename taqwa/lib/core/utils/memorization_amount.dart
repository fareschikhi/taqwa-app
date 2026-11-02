import 'package:flutter/services.dart';

/// A recorded amount as people read it: `2`, not `2.0`, and `1.5` for a half.
///
/// The API sends whole amounts as ints and half pages as doubles, so every
/// screen that prints `amountDone` goes through here instead of `toInt()`,
/// which would quietly turn a half page into a whole one.
String formatAmount(num? amount) {
  final value = amount ?? 0;
  return value == value.truncate() ? '${value.toInt()}' : '$value';
}

/// Arabic keyboards type ٠-٩ and the Arabic decimal separator (or the Arabic
/// comma, on some layouts); Latin keyboards on some locales type a comma. All
/// of them mean the same number.
String _normalizeDigits(String text) {
  const arabicIndic = '٠١٢٣٤٥٦٧٨٩';
  final buffer = StringBuffer();
  for (final char in text.split('')) {
    final index = arabicIndic.indexOf(char);
    if (index >= 0) {
      buffer.write(index);
    } else if (char == ',' || char == '٫' || char == '،') {
      buffer.write('.');
    } else {
      buffer.write(char);
    }
  }
  return buffer.toString();
}

/// The typed amount, or null when it is empty or off the allowed step.
///
/// [allowHalf] permits a trailing `.5` (half a page); nothing finer is ever
/// meant, so `1.3` is rejected rather than rounded.
double? parseAmount(String text, {required bool allowHalf}) {
  var normalized = _normalizeDigits(text.trim());
  if (normalized.endsWith('.')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  final value = double.tryParse(normalized);
  if (value == null) return null;
  final step = allowHalf ? 0.5 : 1;
  return (value / step) == (value / step).truncate() ? value : null;
}

/// Lets the teacher type only amounts on the allowed step: whole numbers, plus
/// a single `.5` when [allowHalf] is set. A keystroke that would make `1.3`
/// is simply not accepted, so there is no invalid value to explain afterwards.
class MemorizationAmountInputFormatter extends TextInputFormatter {
  MemorizationAmountInputFormatter({required this.allowHalf});

  final bool allowHalf;

  static final _whole = RegExp(r'^\d{0,3}$');
  static final _half = RegExp(r'^\d{0,3}(\.5?)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = _normalizeDigits(newValue.text);
    final pattern = allowHalf ? _half : _whole;
    if (!pattern.hasMatch(normalized)) return oldValue;
    return newValue.copyWith(text: normalized);
  }
}
