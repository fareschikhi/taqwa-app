import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../data/models/chat/chat_message_model.dart';

/// One message. The viewer's side sits on the right in the brand colour, the
/// other side on the left as a white card, as in the rest of the app.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.staffView,
    this.onLongPress,
    this.photo,
  });

  final ChatMessageModel message;

  /// Staff see which colleague wrote each staff message; parents never do.
  final bool staffView;

  /// Opens edit/delete. Ignored when the message can't be changed.
  final VoidCallback? onLongPress;

  /// The photo, built by the page (it needs the auth token).
  final Widget? photo;

  bool get _actionable =>
      !message.deleted && (message.canEdit || message.canDelete);

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    final textColor = mine ? AppColors.onPrimary : AppColors.onSurface;
    final metaColor = mine
        ? AppColors.onPrimary.withValues(alpha: 0.8)
        : AppColors.onSurfaceVariant;
    final radius = Radius.circular(AppConstants.radiusLg);
    final tail = Radius.circular(AppConstants.radiusSm);

    final colleague = staffView && message.fromStaff
        ? message.staffSenderName
        : null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 0.78.sw),
        child: Semantics(
          label: message.senderName,
          hint: _actionable ? 'اضغط مطولاً للتعديل أو الحذف' : null,
          child: GestureDetector(
            onLongPress: _actionable ? onLongPress : null,
            child: Container(
              margin: EdgeInsets.symmetric(vertical: 3.h),
              padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
              decoration: BoxDecoration(
                color: mine
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                border: mine
                    ? null
                    : Border.all(color: AppColors.surfaceVariant),
                borderRadius: BorderRadius.only(
                  topLeft: radius,
                  topRight: radius,
                  bottomLeft: mine ? radius : tail,
                  bottomRight: mine ? tail : radius,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (colleague != null) ...[
                    AppText(
                      colleague,
                      style: AppTextStyles.labelSm.copyWith(
                        color: mine
                            ? AppColors.primaryFixed
                            : AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                  ],
                  if (message.deleted)
                    AppText(
                      'تم حذف هذه الرسالة',
                      style: AppTextStyles.labelMd.copyWith(
                        color: metaColor,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  else ...[
                    if (message.hasImage && photo != null) ...[
                      photo!,
                      if (message.body != null) SizedBox(height: 6.h),
                    ],
                    if (message.body != null)
                      AppText(
                        message.body!,
                        style: AppTextStyles.bodyMd.copyWith(color: textColor),
                      ),
                  ],
                  SizedBox(height: 2.h),
                  AppText(
                    message.edited && !message.deleted
                        ? '${_time(message.createdAt)} · معدّلة'
                        : _time(message.createdAt),
                    style: AppTextStyles.labelSm.copyWith(color: metaColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
