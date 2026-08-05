import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../constants/app_constants.dart';

class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.color,
    this.border,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Color? color;
  final Border? border;
  final EdgeInsetsGeometry? margin;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? AppConstants.radiusXl;
    return AnimatedContainer(
      duration: AppConstants.animNormal,
      margin: widget.margin,
      decoration: BoxDecoration(
        color: widget.color ?? AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
        border: widget.border,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(radius),
          onHover: widget.onTap != null
              ? (val) => setState(() => _isHovered = val)
              : null,
          child: Padding(
            padding: widget.padding ??
                EdgeInsets.all(AppConstants.cardPadding),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

