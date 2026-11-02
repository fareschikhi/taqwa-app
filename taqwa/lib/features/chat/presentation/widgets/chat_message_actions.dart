import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text.dart';
import '../../../data/models/chat/chat_message_model.dart';

enum ChatMessageAction { edit, delete }

/// The long-press sheet: only the actions this message allows.
Future<ChatMessageAction?> showChatMessageActions(
  BuildContext context,
  ChatMessageModel message,
) {
  return showModalBottomSheet<ChatMessageAction>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLowest,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppConstants.radiusXl),
      ),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.canEdit)
              ListTile(
                trailing: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.primary,
                ),
                title: AppText(
                  'تعديل',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyMd,
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, ChatMessageAction.edit),
              ),
            if (message.canDelete)
              ListTile(
                trailing: const Icon(
                  Icons.delete_outline,
                  color: AppColors.error,
                ),
                title: AppText(
                  'حذف',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.bodyMd.copyWith(color: AppColors.error),
                ),
                onTap: () =>
                    Navigator.pop(sheetContext, ChatMessageAction.delete),
              ),
          ],
        ),
      ),
    ),
  );
}
