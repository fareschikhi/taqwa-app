import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Taqwa App Constants
/// Border radii, animation durations, and dimensions
class AppConstants {
  AppConstants._();

  // ═══════════════════════════════════════
  // Border Radii
  // ═══════════════════════════════════════
  /// Standard elements: buttons, inputs (12px)
  static double get radiusSm => 4.r;
  static double get radiusDefault => 8.r;
  static double get radiusMd => 12.r;
  /// Content containers: cards, profiles (16px)
  static double get radiusLg => 16.r;
  /// Large cards (24px)
  static double get radiusXl => 24.r;
  /// Pill shape for chips/badges
  static double get radiusFull => 9999.r;

  // ═══════════════════════════════════════
  // Animation Durations
  // ═══════════════════════════════════════
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);

  // ═══════════════════════════════════════
  // Dimensions
  // ═══════════════════════════════════════
  /// Bottom nav bar height
  static double get bottomNavHeight => 72.h;
  /// Primary button height
  static double get buttonHeight => 48.h;
  /// Avatar sizes
  static double get avatarSm => 32.w;
  static double get avatarMd => 40.w;
  static double get avatarLg => 56.w;
  static double get avatarXl => 80.w;
  /// Icon container size in KPI cards
  static double get iconContainerSize => 40.w;
  /// Card padding
  static double get cardPadding => 24.w;

  // ═══════════════════════════════════════
  // Image Picking
  // ═══════════════════════════════════════
  /// Longest edge, in pixels, a picked profile photo is scaled down to.
  /// Nothing shows an avatar larger than this, and a full-resolution camera
  /// photo can exceed the server's 5MB upload limit even at quality 80.
  static const double pickedImageMaxDimension = 1024;
}

