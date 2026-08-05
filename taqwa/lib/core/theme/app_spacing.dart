import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Taqwa Design System Spacing
/// Based on 8px rhythm system
class AppSpacing {
  AppSpacing._();

  static double get xs => 4.w;
  static double get sm => 8.w;
  static double get md => 16.w;
  static double get lg => 24.w;
  static double get xl => 32.w;
  static double get xxl => 48.w;

  /// Gutter between grid items
  static double get gutter => 20.w;

  /// Mobile side margins
  static double get marginMobile => 16.w;

  /// Desktop side margins
  static double get marginDesktop => 40.w;

  // ═══════════════════════════════════════
  // Vertical spacing (using .h)
  // ═══════════════════════════════════════
  static double get xsV => 4.h;
  static double get smV => 8.h;
  static double get mdV => 16.h;
  static double get lgV => 24.h;
  static double get xlV => 32.h;
  static double get xxlV => 48.h;
}

