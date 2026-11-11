import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_shadows.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/avatar_widget.dart';
import 'package:taqwa/features/data/models/student_of_month_model.dart';

/// The award's accent: the app's amber, read as gold beside the brand teal.
const Color _gold = AppColors.gold;

/// طالب الشهر on a dashboard.
///
/// Takes an already-loaded pick, like [HalaqaNewsCard] — the dashboard
/// fetches, this renders. A halaqa whose teacher has not validated yet has no
/// pick, and the dashboard then shows no card at all.
///
/// [isViewer] is set when the winner is the one looking (an adult student) or
/// the child being looked at (a parent): the copy turns into a congratulation
/// instead of an introduction.
class StudentOfMonthCard extends StatelessWidget {
  const StudentOfMonthCard({
    super.key,
    required this.pick,
    this.isViewer = false,
    this.viewerIsParent = false,
  });

  final StudentOfMonthModel pick;
  final bool isViewer;
  final bool viewerIsParent;

  String get _message {
    if (!isViewer) return 'قدوة لزملائه في الحلقة، بارك الله فيه.';
    return viewerIsParent
        ? 'مبارك! اجتهاد ابنكم هذا الشهر جعله الأول في حلقته.'
        : 'مبارك! اجتهادك هذا الشهر جعلك الأول في حلقتك.';
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppConstants.radiusXl);

    return Semantics(
      container: true,
      label: 'طالب شهر ${pick.monthName}: ${pick.fullName}',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: AppColors.surfaceContainerLowest,
          border: Border.all(color: _gold.withValues(alpha: 0.35)),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // A soft gold wash from the avatar's side, fading into the card.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      _gold.withValues(alpha: 0.14),
                      _gold.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            // One large, faint trophy as the card's watermark.
            PositionedDirectional(
              start: -12.w,
              bottom: -18.h,
              child: Icon(
                Icons.emoji_events,
                size: 110.w,
                color: _gold.withValues(alpha: 0.10),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Row(
                children: [
                  Expanded(child: _buildText()),
                  SizedBox(width: 14.w),
                  _WinnerAvatar(pick: pick),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: AppText(
                  'طالب شهر ${pick.monthName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMdBold.copyWith(
                    // Darker than the accent so the label passes contrast on
                    // its own tint.
                    color: const Color(0xFF7A5200),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Icon(Icons.emoji_events, size: 16.w, color: _gold),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        AppText(
          pick.fullName,
          textAlign: TextAlign.end,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.headlineSm.copyWith(
            color: AppColors.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 2.h),
        AppText(
          pick.halaqaName,
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.labelMd.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 8.h),
        AppText(
          _message,
          textAlign: TextAlign.end,
          style: AppTextStyles.bodyMd.copyWith(
            color: isViewer
                ? AppColors.primaryDark
                : AppColors.onSurfaceVariant,
            fontWeight: isViewer ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
  }
}

class _WinnerAvatar extends StatelessWidget {
  const _WinnerAvatar({required this.pick});

  final StudentOfMonthModel pick;

  @override
  Widget build(BuildContext context) {
    final size = AppConstants.avatarXl;

    return SizedBox(
      width: size + 8.w,
      height: size + 8.w,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Gold ring around the photo.
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [Color(0xFFF5C451), _gold],
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(2.w),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                shape: BoxShape.circle,
              ),
              child: AvatarWidget(
                avatarUrl: pick.avatar,
                size: size - 10.w,
                fallback: AppText(
                  pick.fullName.isNotEmpty ? pick.fullName[0] : '؟',
                  style: AppTextStyles.headlineMd.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ),
          // Star badge on the ring.
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: 26.w,
              height: 26.w,
              decoration: BoxDecoration(
                color: _gold,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.surfaceContainerLowest,
                  width: 2,
                ),
              ),
              child: Icon(Icons.star_rounded, size: 16.w, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
