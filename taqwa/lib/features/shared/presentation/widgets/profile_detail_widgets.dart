import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/avatar_widget.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// Building blocks shared by the account details pages (parent, manager):
/// the gradient header, a titled section card, and a labelled info row.

/// Gradient header with back button, page title, photo, name and an
/// active/inactive badge. The edit button shows only when [onEdit] is set.
class ProfileDetailHeader extends StatelessWidget {
  const ProfileDetailHeader({
    super.key,
    required this.title,
    required this.name,
    required this.avatar,
    required this.isActive,
    this.onEdit,
  });

  final String title;
  final String name;
  final String? avatar;
  final bool isActive;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: const BoxDecoration(gradient: AppColors.brandGradient),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: AppColors.onPrimary,
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: 'تعديل',
                  onPressed: onEdit,
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.onPrimary,
                  ),
                ),
              const Spacer(),
              AppText(
                title,
                style: AppTextStyles.headlineMd.copyWith(
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          AvatarWidget(
            avatarUrl: avatar,
            size: 72.w,
            backgroundColor: AppColors.onPrimary.withValues(alpha: 0.2),
            fallback: AppText(
              name.isNotEmpty ? name[0] : '؟',
              style: AppTextStyles.headlineLgMobile.copyWith(
                color: AppColors.onPrimary,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          AppText(
            name,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 6.h),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: AppColors.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            ),
            child: AppText(
              isActive ? 'نشط' : 'غير نشط',
              style: AppTextStyles.labelSm.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A card with a right-aligned section title above [children].
class DetailSectionCard extends StatelessWidget {
  const DetailSectionCard({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          AppText(
            title,
            style: AppTextStyles.headlineSm.copyWith(
              color: AppColors.onSurface,
            ),
          ),
          SizedBox(height: 12.h),
          ...children,
        ],
      ),
    );
  }
}

/// A labelled field with an icon. A missing value reads "غير مسجل" rather
/// than being hidden, so an admin can see at a glance what the account lacks.
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isLtr = false,
  });

  final IconData icon;
  final String label;
  final String? value;

  /// Phone numbers and emails keep left-to-right order inside the RTL layout.
  final bool isLtr;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null && value!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppText(
                label,
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 2.h),
              AppText(
                hasValue ? value!.trim() : 'غير مسجل',
                style: AppTextStyles.bodyMd.copyWith(
                  color: hasValue ? AppColors.onSurface : AppColors.outline,
                ),
                textAlign: TextAlign.end,
                textDirection: hasValue && isLtr ? TextDirection.ltr : null,
              ),
            ],
          ),
        ),
        SizedBox(width: 12.w),
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          ),
          child: Icon(icon, size: 18.w, color: AppColors.primary),
        ),
      ],
    );
  }
}
