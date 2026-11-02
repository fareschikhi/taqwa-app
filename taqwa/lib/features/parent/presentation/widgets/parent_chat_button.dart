import 'package:flutter/material.dart';
import '../../../chat/presentation/pages/chat_thread_page.dart';
import '../../../chat/presentation/widgets/chat_icon_button.dart';
import '../../../data/models/chat/chat_target.dart';

/// The parent's way into their chat with "الإدارة", in the top bar of every
/// parent page, with a dot while a staff message is unread.
class ParentChatButton extends StatelessWidget {
  const ParentChatButton({super.key, this.onBrand = false});

  /// Light colours, for headers drawn on the brand gradient.
  final bool onBrand;

  @override
  Widget build(BuildContext context) => ChatIconButton(
    label: 'محادثة الإدارة',
    onBrand: onBrand,
    open: (context) => Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatThreadPage(
          target: ChatTarget.mine(),
          title: 'الإدارة',
        ),
      ),
    ),
  );
}
