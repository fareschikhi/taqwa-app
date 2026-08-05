import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/app_shadows.dart';
import '../constants/app_constants.dart';

/// User card for teacher / parent / student lists
class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.avatarInitial,
    this.avatarBgColor,
    this.status,
    this.statusColor,
    this.onTap,
    this.actions,
    this.trailing,
    this.children,
  });

  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final String? avatarInitial;
  final Color? avatarBgColor;
  final String? status;
  final Color? statusColor;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final Widget? trailing;
  final List<Widget>? children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        boxShadow: AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusXl),
          child: Padding(
            padding: EdgeInsets.all(AppConstants.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    if (status != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: (statusColor ?? AppColors.primary)
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusFull,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(
                                color: statusColor ?? AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              status!,
                              style: AppTextStyles.labelSm.copyWith(
                                color: statusColor ?? AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const Spacer(),
                    // Avatar
                    _buildAvatar(),
                  ],
                ),
                SizedBox(height: 12.h),
                // Name
                Text(
                  name,
                  style: AppTextStyles.headlineSm.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.end,
                ),
                if (subtitle != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle!,
                    style: AppTextStyles.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
                if (trailing != null) ...[
                  SizedBox(height: 16.h),
                  trailing!,
                ],
                if (children != null) ...[
                  SizedBox(height: 16.h),
                  ...children!,
                ],
                if (actions != null) ...[
                  SizedBox(height: 16.h),
                  const Divider(),
                  SizedBox(height: 12.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: actions!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (avatarUrl != null) {
      return Container(
        width: AppConstants.avatarLg,
        height: AppConstants.avatarLg,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primaryContainer,
            width: 2,
          ),
        ),
        child: ClipOval(
          child: Image.network(
            avatarUrl!,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => _buildInitialAvatar(),
          ),
        ),
      );
    }
    return _buildInitialAvatar();
  }

  Widget _buildInitialAvatar() {
    return Container(
      width: AppConstants.avatarLg,
      height: AppConstants.avatarLg,
      decoration: BoxDecoration(
        color: avatarBgColor ?? AppColors.primaryContainer,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          avatarInitial ?? (name.isNotEmpty ? name[0] : '؟'),
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

