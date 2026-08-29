import 'package:flutter/material.dart';

/// Text whose base direction follows what it says.
///
/// The app tree is deliberately left-to-right: every screen aligns itself
/// explicitly, and flipping `Directionality` would mirror every `Row`. But a
/// paragraph's base direction also decides where its *leading and trailing
/// neutral characters* sit, so under LTR an Arabic sentence ending in '.' or a
/// field label ending in '*' renders that character on the wrong side.
///
/// Forcing RTL instead would break the other half: percentages, dates and
/// Latin names would reorder. So the direction is chosen per string — Arabic
/// present means RTL, anything else stays LTR — and an explicit
/// [textDirection] always overrides the guess.
class AppText extends StatelessWidget {
  const AppText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.overflow,
    this.maxLines,
    this.softWrap,
    this.textDirection,
    this.locale,
    this.semanticsLabel,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final TextOverflow? overflow;
  final int? maxLines;
  final bool? softWrap;

  /// Set this to override the guess — a Latin string that must read RTL, or
  /// an Arabic one that must not.
  final TextDirection? textDirection;

  final Locale? locale;
  final String? semanticsLabel;

  /// Arabic, Arabic Supplement, Arabic Extended-A, and the presentation forms.
  static final RegExp _rtlScript = RegExp(
    r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]',
  );

  /// Exposed so callers and tests can ask the same question the widget asks.
  static TextDirection directionOf(String text) =>
      _rtlScript.hasMatch(text) ? TextDirection.rtl : TextDirection.ltr;

  @override
  Widget build(BuildContext context) {
    return Text(
      data,
      style: style,
      textAlign: textAlign,
      overflow: overflow,
      maxLines: maxLines,
      softWrap: softWrap,
      textDirection: textDirection ?? directionOf(data),
      locale: locale,
      semanticsLabel: semanticsLabel,
    );
  }
}
