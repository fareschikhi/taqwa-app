import 'package:flutter/material.dart';

/// Taqwa Design System Colors
/// Extracted from the design files in taqwa_design/
/// Based on Material 3 teal-based color scheme
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════
  // Primary
  // ═══════════════════════════════════════
  static const Color primary = Color(0xFF006B57);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF7FD8BE);
  static const Color onPrimaryContainer = Color(0xFF005F4D);
  static const Color inversePrimary = Color(0xFF7ED7BD);
  static const Color primaryFixed = Color(0xFF9AF4D9);
  static const Color primaryFixedDim = Color(0xFF7ED7BD);
  static const Color onPrimaryFixed = Color(0xFF002019);
  static const Color onPrimaryFixedVariant = Color(0xFF005141);

  // ═══════════════════════════════════════
  // Secondary
  // ═══════════════════════════════════════
  static const Color secondary = Color(0xFF146871);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFA3ECF6);
  static const Color onSecondaryContainer = Color(0xFF1B6C75);
  static const Color secondaryFixed = Color(0xFFA6EEF9);
  static const Color secondaryFixedDim = Color(0xFF8AD2DC);
  static const Color onSecondaryFixed = Color(0xFF001F23);
  static const Color onSecondaryFixedVariant = Color(0xFF004F56);

  // ═══════════════════════════════════════
  // Tertiary
  // ═══════════════════════════════════════
  static const Color tertiary = Color(0xFF43636B);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFABCDD6);
  static const Color onTertiaryContainer = Color(0xFF38585F);
  static const Color tertiaryFixed = Color(0xFFC6E8F1);
  static const Color tertiaryFixedDim = Color(0xFFABCCD5);
  static const Color onTertiaryFixed = Color(0xFF001F25);
  static const Color onTertiaryFixedVariant = Color(0xFF2B4B53);

  // ═══════════════════════════════════════
  // Error
  // ═══════════════════════════════════════
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // ═══════════════════════════════════════
  // Surface & Background
  // ═══════════════════════════════════════
  static const Color surface = Color(0xFFF6FAF7);
  static const Color surfaceDim = Color(0xFFD7DBD8);
  static const Color surfaceBright = Color(0xFFF6FAF7);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF1F5F1);
  static const Color surfaceContainer = Color(0xFFEBEFEB);
  static const Color surfaceContainerHigh = Color(0xFFE5E9E6);
  static const Color surfaceContainerHighest = Color(0xFFDFE3E0);
  static const Color surfaceVariant = Color(0xFFDFE3E0);
  static const Color onSurface = Color(0xFF181D1B);
  static const Color onSurfaceVariant = Color(0xFF3E4945);
  static const Color inverseSurface = Color(0xFF2D312F);
  static const Color inverseOnSurface = Color(0xFFEEF2EE);
  static const Color surfaceTint = Color(0xFF006B57);
  static const Color background = Color(0xFFF6FAF7);
  static const Color onBackground = Color(0xFF181D1B);

  // ═══════════════════════════════════════
  // Outline
  // ═══════════════════════════════════════
  static const Color outline = Color(0xFF6E7A75);
  static const Color outlineVariant = Color(0xFFBDC9C3);

  // ═══════════════════════════════════════
  // Brand Gradient
  // ═══════════════════════════════════════
  static const Color gradientStart = Color(0xFF7FD8BE);
  static const Color gradientEnd = Color(0xFF1F6F78);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradientStart, gradientEnd],
  );

  // ═══════════════════════════════════════
  // Semantic Colors
  // ═══════════════════════════════════════
  static const Color success = Color(0xFF006B57);
  static const Color warning = Color(0xFFE6A817);
  static const Color info = Color(0xFF146871);

  // ═══════════════════════════════════════
  // Attendance Status Colors
  // ═══════════════════════════════════════
  static const Color present = Color(0xFF006B57);
  static const Color absent = Color(0xFFBA1A1A);
  static const Color late = Color(0xFFE6A817);

  // ═══════════════════════════════════════
  // Input Field
  // ═══════════════════════════════════════
  static const Color inputBorder = Color(0xFFE7ECEC);
  static const Color inputFocusBorder = Color(0xFF7FD8BE);
  static const Color inputPlaceholder = Color(0xFFA0B1B5);

  // ═══════════════════════════════════════
  // Typography Colors (from design spec)
  // ═══════════════════════════════════════
  static const Color textPrimary = Color(0xFF12343B);
  static const Color textSecondary = Color(0xFF5C7277);
}

