import 'package:flutter/material.dart';

/// Taqwa Design System Colors
/// Brand green #009000, from the Stitch parent design (design/parent/).
///
/// White on #009000 is only 4.2:1, under the 4.5:1 that small text needs.
/// So #009000 fills large shapes (hero cards, active tab, icons, big
/// numbers) and [primaryDark] carries small green text on white and small
/// white text on green, filled buttons included.
class AppColors {
  AppColors._();

  // ═══════════════════════════════════════
  // Primary
  // ═══════════════════════════════════════
  static const Color primary = Color(0xFF009000);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// 5.6:1 both ways against white: links, small green labels, buttons.
  static const Color primaryDark = Color(0xFF007A00);

  /// The soft tint behind selected chips, the active tab and unread items.
  static const Color primaryContainer = Color(0xFFE6F4E6);
  static const Color onPrimaryContainer = Color(0xFF005A00);
  static const Color inversePrimary = Color(0xFF7EDC72);
  static const Color primaryFixed = Color(0xFFC8F0C2);
  static const Color primaryFixedDim = Color(0xFF9FE394);
  static const Color onPrimaryFixed = Color(0xFF002200);
  static const Color onPrimaryFixedVariant = Color(0xFF005300);

  // ═══════════════════════════════════════
  // Secondary (teal-green): second memorization type, secondary accents
  // ═══════════════════════════════════════
  static const Color secondary = Color(0xFF0E7C66);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD2F0E8);
  static const Color onSecondaryContainer = Color(0xFF00513F);
  static const Color secondaryFixed = Color(0xFFD2F0E8);
  static const Color secondaryFixedDim = Color(0xFFA8DCCD);
  static const Color onSecondaryFixed = Color(0xFF002019);
  static const Color onSecondaryFixedVariant = Color(0xFF00513F);

  // ═══════════════════════════════════════
  // Tertiary (olive): third memorization type
  // ═══════════════════════════════════════
  static const Color tertiary = Color(0xFF66751A);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFEEF2D2);
  static const Color onTertiaryContainer = Color(0xFF3D4700);
  static const Color tertiaryFixed = Color(0xFFEEF2D2);
  static const Color tertiaryFixedDim = Color(0xFFD6DEA0);
  static const Color onTertiaryFixed = Color(0xFF1B2100);
  static const Color onTertiaryFixedVariant = Color(0xFF3D4700);

  // ═══════════════════════════════════════
  // Error
  // ═══════════════════════════════════════
  static const Color error = Color(0xFFC62828);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFDE3E3);
  static const Color onErrorContainer = Color(0xFF8E1010);

  // ═══════════════════════════════════════
  // Surface & Background
  // ═══════════════════════════════════════
  static const Color surface = Color(0xFFF5F8F5);
  static const Color surfaceDim = Color(0xFFD5DBD5);
  static const Color surfaceBright = Color(0xFFF5F8F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF0F4F0);
  static const Color surfaceContainer = Color(0xFFEAEFEA);
  static const Color surfaceContainerHigh = Color(0xFFE4EAE4);
  static const Color surfaceContainerHighest = Color(0xFFDEE5DE);
  static const Color surfaceVariant = Color(0xFFDEE5DE);
  static const Color onSurface = Color(0xFF152015);
  static const Color onSurfaceVariant = Color(0xFF5A6A5A);
  static const Color inverseSurface = Color(0xFF2A332A);
  static const Color inverseOnSurface = Color(0xFFEDF3ED);
  static const Color surfaceTint = primary;
  static const Color background = Color(0xFFF5F8F5);
  static const Color onBackground = Color(0xFF152015);

  // ═══════════════════════════════════════
  // Outline
  // ═══════════════════════════════════════
  static const Color outline = Color(0xFF6F7D6F);
  static const Color outlineVariant = Color(0xFFCBD6CB);

  /// The hairline around white cards: lighter than [outlineVariant], which
  /// still has to read as a control border.
  static const Color cardBorder = Color(0xFFE3EAE3);

  // ═══════════════════════════════════════
  // Brand Gradient (hero cards only)
  // ═══════════════════════════════════════
  static const Color gradientStart = primary;

  /// Dark enough that the small white labels at the bottom of a hero card
  /// stay readable.
  static const Color gradientEnd = Color(0xFF006400);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [gradientStart, gradientEnd],
  );

  // ═══════════════════════════════════════
  // Accent: student of the month only
  // ═══════════════════════════════════════
  static const Color gold = Color(0xFFC9A227);

  // ═══════════════════════════════════════
  // Semantic Colors
  // ═══════════════════════════════════════
  static const Color success = primary;
  static const Color warning = Color(0xFFE6A817);
  static const Color info = Color(0xFF1F6FB2);

  // ═══════════════════════════════════════
  // Attendance Status Colors
  // ═══════════════════════════════════════
  /// primaryDark, not primary: it is also the colour of the "حاضر" label on
  /// its own 12% tint, where the brand green would fall under 4.5:1.
  static const Color present = primaryDark;
  static const Color absent = error;

  /// Darker than [warning] because it is used as text: 5:1 on white.
  static const Color late = Color(0xFFB26A00);

  /// عذر: calm blue, so it reads as neither good (present) nor bad (absent).
  static const Color excused = info;

  // ═══════════════════════════════════════
  // Input Field
  // ═══════════════════════════════════════
  static const Color inputBorder = Color(0xFFDDE5DD);
  static const Color inputFocusBorder = primary;
  static const Color inputPlaceholder = Color(0xFF8E9D8E);

  // ═══════════════════════════════════════
  // Typography Colors
  // ═══════════════════════════════════════
  static const Color textPrimary = onSurface;
  static const Color textSecondary = onSurfaceVariant;
}
