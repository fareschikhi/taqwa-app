import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/providers/chat_unread_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../chat/presentation/pages/chat_thread_page.dart';
import '../../../data/models/chat/chat_target.dart';

/// The parent's way into their chat with "الإدارة", in the top bar of every
/// parent page, with a dot while a staff message is unread.
class ParentChatButton extends ConsumerWidget {
  const ParentChatButton({super.key, this.onBrand = false});

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
      label: unread > 0 ? 'محادثة الإدارة، رسائل جديدة' : 'محادثة الإدارة',
      child: Tooltip(
        message: 'محادثة الإدارة',
        child: Material(
          color: background,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChatThreadPage(
                    target: ChatTarget.mine(),
                    title: 'الإدارة',
                  ),
                ),
              );
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
