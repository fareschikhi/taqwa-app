import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/models/halaqa/halaqa_announcement_model.dart';

/// How many announcements a dashboard shows before deferring to the history.
const int kNewsPreviewCount = 3;

/// أخبار الحلقة on a dashboard: what the circle has been told lately.
///
/// Takes an already-loaded list, like [LastSessionCard] — the dashboard
/// fetches, this renders. Nothing here knows which role is looking; the feed
/// arrives already scoped by the server.
///
/// Renders nothing at all when there is no news and the viewer cannot post
/// one: the dashboards are dense already and an empty box teaches a reader
/// nothing. A manager or admin still sees the card, because they are the ones
/// who need to find the compose action.
///
/// [onEdit] and [onDelete] put the same per-item icons on each row as the
/// history page has, so a typo in the latest news is fixed where it is seen
/// instead of behind `عرض الكل`, which only appears past [kNewsPreviewCount].
class HalaqaNewsCard extends StatelessWidget {
  const HalaqaNewsCard({
    super.key,
    required this.announcements,
    this.onSeeAll,
    this.onCompose,
    this.canCompose = false,
    this.onEdit,
    this.onDelete,
  });

  final List<HalaqaAnnouncementModel> announcements;
  final VoidCallback? onSeeAll;
  final VoidCallback? onCompose;
  final bool canCompose;
  final ValueChanged<HalaqaAnnouncementModel>? onEdit;
  final ValueChanged<HalaqaAnnouncementModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty && !canCompose) return const SizedBox.shrink();

    final preview = announcements.take(kNewsPreviewCount).toList();
    final hasMore = announcements.length > preview.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildHeader(),
        SizedBox(height: 12.h),
        AppCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (preview.isEmpty)
                AppText(
                  'لا توجد أخبار',
                  style: AppTextStyles.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                )
              else
                ...preview.map(
                  (a) => _NewsRow(
                    announcement: a,
                    isLast: a == preview.last,
                    onEdit: onEdit,
                    onDelete: onDelete,
                  ),
                ),
              if (hasMore && onSeeAll != null) ...[
                SizedBox(height: 4.h),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onSeeAll,
                    child: AppText(
                      'عرض الكل',
                      style: AppTextStyles.labelMdBold.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        if (canCompose && onCompose != null)
          TextButton.icon(
            onPressed: onCompose,
            icon: Icon(Icons.add, size: 18.w, color: AppColors.primary),
            label: AppText(
              'إضافة خبر',
              style: AppTextStyles.labelMdBold.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        const Spacer(),
        AppText(
          'أخبار الحلقة',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
      ],
    );
  }
}

class _NewsRow extends StatelessWidget {
  const _NewsRow({
    required this.announcement,
    required this.isLast,
    this.onEdit,
    this.onDelete,
  });

  final HalaqaAnnouncementModel announcement;
  final bool isLast;
  final ValueChanged<HalaqaAnnouncementModel>? onEdit;
  final ValueChanged<HalaqaAnnouncementModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              if (onEdit != null)
                IconButton(
                  icon: Icon(
                    Icons.edit_outlined,
                    size: 18.w,
                    color: AppColors.onSurfaceVariant,
                  ),
                  tooltip: 'تعديل',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onEdit!(announcement),
                ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18.w,
                    color: AppColors.error,
                  ),
                  tooltip: 'حذف',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onDelete!(announcement),
                ),
              Expanded(
                child: AppText(
                  announcement.title,
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.onSurface,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // The halaqa name shows on every item rather than only when the
          // viewer spans several circles: one rule, no branch that can be
          // wrong about which case this is. An all-halaqas post can name many,
          // so the names give way to an ellipsis here and the date never does;
          // the history page shows the whole list.
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppText(
                '${announcement.formattedDate} · ',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Flexible(
                child: AppText(
                  announcement.halaqaLabel,
                  style: AppTextStyles.labelSm.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          AppText(
            announcement.body,
            style: AppTextStyles.bodyMd.copyWith(color: AppColors.onSurface),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isLast) ...[
            SizedBox(height: 12.h),
            Divider(height: 1, color: AppColors.outlineVariant),
          ],
        ],
      ),
    );
  }
}
