import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cairo and Tajawal have no glyph for ڨ (U+06A8), which is common in
/// Algerian names (بڨار, ڨاسم). Without an explicit fallback the engine
/// picks an arbitrary system font for that one letter, so it renders in a
/// foreign style and breaks the word's joining. Noto Kufi Arabic carries ڨ
/// and shares Cairo's geometric Kufi shapes, so the letter blends in.
class AppFonts {
  AppFonts._();

  static TextStyle cairo({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => _withFallback(
    GoogleFonts.cairo(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    ),
  );

  static TextStyle tajawal({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => _withFallback(
    GoogleFonts.tajawal(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    ),
  );

  /// Naskh for fully vocalised religious text. Cairo's Kufi forms crowd the
  /// tashkeel; Amiri was drawn for Quranic and hadith typesetting, so every
  /// shadda and tanween sits where a reader expects it.
  static TextStyle amiri({
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    Color? color,
  }) => _withFallback(
    GoogleFonts.amiri(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    ),
  );

  /// Fallback family list for [ThemeData.fontFamilyFallback].
  static List<String> fallbackFor([FontWeight? weight]) => [
    // Calling the GoogleFonts getter is what registers and loads the
    // weight; its family name alone would point at nothing.
    GoogleFonts.notoKufiArabic(fontWeight: weight).fontFamily!,
  ];

  static TextStyle _withFallback(TextStyle style) => style.copyWith(
    fontFamilyFallback: [
      ...fallbackFor(style.fontWeight),
      ...?style.fontFamilyFallback,
    ],
  );
}
