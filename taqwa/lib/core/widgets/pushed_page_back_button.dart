import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../theme/app_colors.dart';

/// Round back button for a page that is normally a shell tab but has been
/// pushed on its own (e.g. a parent's history pages opened by staff from a
/// student's profile). Same size and surface as the chat shortcut it stands
/// in for, so the header keeps its layout either way.
class PushedPageBackButton extends StatelessWidget {
  const PushedPageBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'رجوع',
      child: Material(
        color: AppColors.surfaceContainerLowest,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.cardBorder),
        ),
        elevation: 1,
        shadowColor: const Color.fromRGBO(0, 40, 0, 0.2),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => Navigator.maybePop(context),
          child: SizedBox(
            width: 48.w,
            height: 48.w,
            child: Semantics(
              button: true,
              label: 'رجوع',
              excludeSemantics: true,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 20.w,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
