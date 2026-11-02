import 'package:flutter/material.dart';
import '../pages/chat_inbox_page.dart';
import 'chat_icon_button.dart';

/// A manager's way into the parents' conversations, in the dashboard's top
/// bar. A sixth bottom tab didn't fit a phone's width, so it lives here.
class StaffChatButton extends StatelessWidget {
  const StaffChatButton({super.key});

  @override
  Widget build(BuildContext context) => ChatIconButton(
    label: 'المحادثات',
    open: (context) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChatInboxPage()),
    ),
  );
}
