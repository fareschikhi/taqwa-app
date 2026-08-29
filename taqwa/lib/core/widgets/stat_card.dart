import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../constants/app_constants.dart';

/// KPI / Statistics card matching admin dashboard design
class StatCard extends StatefulWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.iconColor,
    this.iconBgColor,
    this.bubbleColor,
    this.valueColor,
    this.onTap,
    this.trend,
    this.trendPositive,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBgColor;
  final Color? bubbleColor;
  final Color? valueColor;
  final VoidCallback? onTap;
  final String? trend;
  final bool? trendPositive;

  @override
  State<StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<StatCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.iconColor ?? AppColors.primary;
    final iconBgColor = widget.iconBgColor ?? AppColors.primaryContainer;
    final bubbleColor = widget.bubbleColor ?? AppColors.primaryContainer;
    final valueColor = widget.valueColor ?? AppColors.onSurface;

    return GestureDetector(
      onTap: widget.onTap,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: AppConstants.animNormal,
          height: 130.h,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            boxShadow: _isHovered ? AppShadows.cardHover : AppShadows.card,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusXl),
            child: Stack(
              children: [
                // Decorative bubble (top-right)
                Positioned(
                  right: -12.w,
                  top: -12.h,
                  child: AnimatedContainer(
                    duration: AppConstants.animSlow,
                    width: _isHovered ? 120.w : 100.w,
                    height: _isHovered ? 100.w : 80.w,
                    decoration: BoxDecoration(
                      color: bubbleColor.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                // Content
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon container
                          Container(
                            width: 40.w,
                            height: 40.w,
                            decoration: BoxDecoration(
                              color: iconBgColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusMd,
                              ),
                            ),
                            child: Icon(
                              widget.icon,
                              color: iconColor,
                              size: 20.w,
                            ),
                          ),
                          // Value
                          Text(
                            widget.value,
                            style: AppTextStyles.headlineMd.copyWith(
                              color: valueColor,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (widget.trend != null)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6.w,
                                vertical: 2.h,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (widget.trendPositive == true
                                            ? AppColors.primary
                                            : AppColors.error)
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusFull,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.trendPositive == true
                                        ? Icons.arrow_upward
                                        : Icons.arrow_downward,
                                    size: 10.w,
                                    color: widget.trendPositive == true
                                        ? AppColors.primary
                                        : AppColors.error,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    widget.trend!,
                                    style: AppTextStyles.caption.copyWith(
                                      color: widget.trendPositive == true
                                          ? AppColors.primary
                                          : AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          // Label
                          Text(
                            widget.label,
                            style: AppTextStyles.labelSm.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
