/// Points arrive from the API as exact decimal strings ("12.5", "-1") so the
/// server's sum is never bent by a float on the way. They only become numbers
/// here, for display.
num parsePoints(Object? raw) {
  if (raw is num) return raw;
  if (raw is String) return num.tryParse(raw) ?? 0;
  return 0;
}

/// Two decimals at most, trailing zeros trimmed: 12.5, 2, 0.13.
String _trim(num value) {
  var text = value.toStringAsFixed(2);
  if (text.contains('.')) {
    text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  // A tiny negative rounds to "-0", which is not a number anyone has.
  return text == '-0' ? '0' : text;
}

/// A total, with its unit. Unlike a fine balance this is never clamped: a
/// student who lost more than he earned really is below zero.
///
/// The leading LRM (U+200E) pins the number left-to-right: the string is
/// Arabic, so it is laid out RTL, and without the mark "-3" would render "3-".
String formatPoints(num value) => '‎${_trim(value)} نقطة';

/// One history row's amount, always signed so a gain and a loss read apart.
String formatSignedPoints(num value) {
  final text = _trim(value);
  return value > 0 && text != '0' ? '+$text' : text;
}
