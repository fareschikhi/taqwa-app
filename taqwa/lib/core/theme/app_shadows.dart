import 'package:flutter/material.dart';

/// Taqwa Design System Shadows
/// Based on tonal layering with ambient shadows
class AppShadows {
  AppShadows._();

  /// Level 1 - Cards/Containers: "whisper shadow"
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color.fromRGBO(18, 52, 59, 0.04),
      offset: Offset(0, 4),
      blurRadius: 20,
    ),
  ];

  /// Level 1 - Cards hover state
  static const List<BoxShadow> cardHover = [
    BoxShadow(
      color: Color.fromRGBO(18, 52, 59, 0.08),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Level 2 - Popovers/Modals
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color.fromRGBO(18, 52, 59, 0.08),
      offset: Offset(0, 12),
      blurRadius: 32,
    ),
  ];

  /// Bottom navigation bar shadow
  static const List<BoxShadow> bottomNav = [
    BoxShadow(
      color: Color.fromRGBO(18, 52, 59, 0.04),
      offset: Offset(0, -4),
      blurRadius: 20,
    ),
  ];

  /// Subtle shadow for inputs/buttons
  static const List<BoxShadow> subtle = [
    BoxShadow(
      color: Color.fromRGBO(18, 52, 59, 0.02),
      offset: Offset(0, 2),
      blurRadius: 8,
    ),
  ];
}

