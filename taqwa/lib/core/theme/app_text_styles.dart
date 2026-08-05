import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Taqwa Design System Text Styles
/// Typography: Cairo for headlines/body, Tajawal for labels
class AppTextStyles {
  AppTextStyles._();

  // ═══════════════════════════════════════
  // Display
  // ═══════════════════════════════════════
  static TextStyle get displayLg => GoogleFonts.cairo(
        fontSize: 40.sp,
        fontWeight: FontWeight.w700,
        height: 56 / 40,
      );

  // ═══════════════════════════════════════
  // Headlines
  // ═══════════════════════════════════════
  static TextStyle get headlineLg => GoogleFonts.cairo(
        fontSize: 32.sp,
        fontWeight: FontWeight.w700,
        height: 44 / 32,
      );

  static TextStyle get headlineLgMobile => GoogleFonts.cairo(
        fontSize: 28.sp,
        fontWeight: FontWeight.w700,
        height: 38 / 28,
      );

  static TextStyle get headlineMd => GoogleFonts.cairo(
        fontSize: 24.sp,
        fontWeight: FontWeight.w600,
        height: 34 / 24,
      );

  static TextStyle get headlineSm => GoogleFonts.cairo(
        fontSize: 20.sp,
        fontWeight: FontWeight.w600,
        height: 28 / 20,
      );

  // ═══════════════════════════════════════
  // Body
  // ═══════════════════════════════════════
  static TextStyle get bodyLg => GoogleFonts.cairo(
        fontSize: 18.sp,
        fontWeight: FontWeight.w400,
        height: 28 / 18,
      );

  static TextStyle get bodyMd => GoogleFonts.cairo(
        fontSize: 16.sp,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
      );

  static TextStyle get bodyMdBold => GoogleFonts.cairo(
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
        height: 24 / 16,
      );

  // ═══════════════════════════════════════
  // Labels (Tajawal)
  // ═══════════════════════════════════════
  static TextStyle get labelMd => GoogleFonts.tajawal(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0.02 * 14,
      );

  static TextStyle get labelMdBold => GoogleFonts.tajawal(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        height: 20 / 14,
        letterSpacing: 0.02 * 14,
      );

  static TextStyle get labelSm => GoogleFonts.tajawal(
        fontSize: 12.sp,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
      );

  // ═══════════════════════════════════════
  // Utility Styles
  // ═══════════════════════════════════════
  static TextStyle get caption => GoogleFonts.tajawal(
        fontSize: 10.sp,
        fontWeight: FontWeight.w400,
        height: 14 / 10,
      );

  static TextStyle get button => GoogleFonts.tajawal(
        fontSize: 14.sp,
        fontWeight: FontWeight.w700,
        height: 20 / 14,
      );
}

