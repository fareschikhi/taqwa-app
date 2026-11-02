import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/providers/chat_unread_provider.dart';
import '../../../../core/theme/app_colors.dart';

/// The round chat entry in a top bar, with a red dot while something is
/// unread. Parents and managers share it so both entries look the same.
class ChatIconButton extends ConsumerWidget {
  const ChatIconButton({
    super.key,
    required this.label,
    required this.open,
    this.onBrand = false,
  });

  /// Tooltip and screen-reader name; ", رسائل جديدة" is added while unread.
  final String label;

  /// Opens the chat; the unread count is refreshed once it returns.
  final Future<void> Function(BuildContext context) open;

  /// Light colours, for headers drawn on the brand gradient.
  final bool onBrand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(chatUnreadProvider);
    final iconColor = onBrand ? AppColors.onPrimary : AppColors.primary;
    final background = onBrand
        ? AppColors.onPrimary.withValues(alpha: 0.2)
        : AppColors.primaryContainer.withValues(alpha: 0.35);

    return Semantics(
      button: true,
      label: unread > 0 ? '$label، رسائل جديدة' : label,
      child: Tooltip(
        message: label,
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              await open(context);
              ref.read(chatUnreadProvider.notifier).refresh();
            },
            child: SizedBox(
              width: 40.w,
              height: 40.w,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 22.w, color: iconColor),
                  if (unread > 0)
                    Positioned(
                      top: 8.w,
                      right: 8.w,
                      child: Container(
                        key: const Key('chat-unread-dot'),
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          color: AppColors.error,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: onBrand
                                ? AppColors.primary
                                : AppColors.surfaceContainerLowest,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
