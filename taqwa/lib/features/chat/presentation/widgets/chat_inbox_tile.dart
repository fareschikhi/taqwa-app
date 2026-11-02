import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../../core/widgets/avatar_widget.dart';
import '../../../data/models/chat/chat_inbox_item_model.dart';

/// One parent in the staff inbox or the new-chat picker: name, children,
/// last message and this staff member's own unread count.
class ChatInboxTile extends StatelessWidget {
  const ChatInboxTile({super.key, required this.item, required this.onTap});

  final ChatInboxItemModel item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = item.unread > 0;
    final secondLine = item.preview ?? item.childrenLabel;

    return Material(
      color: AppColors.surfaceContainerLowest,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.surfaceContainer),
            ),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.lastAt != null)
                    AppText(
                      _when(item.lastAt!),
                      style: AppTextStyles.labelSm.copyWith(
                        color: unread
                            ? AppColors.primary
                            : AppColors.onSurfaceVariant,
                      ),
                    ),
                  SizedBox(height: 4.h),
                  if (unread)
                    Container(
                      constraints: BoxConstraints(minWidth: 22.w),
                      padding: EdgeInsets.symmetric(
                        horizontal: 6.w,
                        vertical: 1.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusFull,
                        ),
                      ),
                      child: AppText(
                        '${item.unread}',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    AppText(
                      item.parentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMd.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                    if (secondLine.isNotEmpty)
                      AppText(
                        secondLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelMd.copyWith(
                          color: unread
                              ? AppColors.onSurface
                              : AppColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              AvatarWidget(
                avatarUrl: item.parentAvatar,
                size: 44.w,
                fallback: AppText(
                  item.parentName.isNotEmpty ? item.parentName[0] : '؟',
                  style: AppTextStyles.bodyMdBold.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Time today, "أمس", otherwise the date.
  static String _when(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    if (day == today) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (day == today.subtract(const Duration(days: 1))) return 'أمس';
    return '${t.day}/${t.month}';
  }
}
