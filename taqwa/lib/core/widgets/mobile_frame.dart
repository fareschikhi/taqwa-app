import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// Widest the app is laid out, in logical pixels.
///
/// The screens are designed for a phone, so a wider window (a desktop
/// browser) shows them in a centred column of this width instead of
/// stretching them across it.
const double kMobileFrameMaxWidth = 440;

/// Points ScreenUtil at the capped width rather than the real window.
///
/// ScreenUtilInit measures the window itself and ignores any MediaQuery
/// above it, so on a 1440px browser `.w` would scale by 1440 / 390. Call this
/// from ScreenUtilInit's builder: it runs again on every resize, right after
/// ScreenUtilInit has configured itself from the window.
void configureScreenUtilForMobileFrame(BuildContext context) {
  final view = View.maybeOf(context);
  if (view == null) return;
  final data = MediaQueryData.fromView(view);
  if (data.size.width <= kMobileFrameMaxWidth) return;
  ScreenUtil.configure(data: _capped(data));
}

MediaQueryData _capped(MediaQueryData data) => data.copyWith(
      size: Size(min(data.size.width, kMobileFrameMaxWidth), data.size.height),
    );

/// Lays the app out in a phone-width column when the window is wider.
///
/// Wraps the Navigator (MaterialApp.builder), so dialogs, bottom sheets and
/// snack bars stay inside the column too. Screens that read
/// `MediaQuery.size` see the column's width, not the window's.
class MobileFrame extends StatelessWidget {
  const MobileFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final data = MediaQuery.of(context);
    if (data.size.width <= kMobileFrameMaxWidth) return child;

    return ColoredBox(
      color: AppColors.surfaceContainerHigh,
      child: Center(
        child: Container(
          width: kMobileFrameMaxWidth,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 24,
              ),
            ],
          ),
          child: MediaQuery(data: _capped(data), child: child),
        ),
      ),
    );
  }
}
