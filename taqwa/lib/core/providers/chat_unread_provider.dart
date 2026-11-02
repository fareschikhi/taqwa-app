import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/data/models/chat/chat_target.dart';
import '../../features/data/models/user_model.dart';
import '../../features/data/repositories/chat_repository.dart';
import 'auth_provider.dart';

/// The signed-in user's unread chat count: staff messages for a parent, the
/// parents' messages after their own read marker for an admin or chat
/// manager. Drives the parent's top-bar dot and the staff tab/drawer badge.
///
/// Refreshed on demand (shell start, a push arriving, leaving a thread)
/// rather than polled, so an idle app makes no requests.
class ChatUnreadNotifier extends Notifier<int> {
  @override
  int build() => 0;

  Future<void> refresh() async {
    final user = ref.read(authProvider).user;
    final bool staff;
    if (user?.role == UserRole.parent) {
      staff = false;
    } else if (canUseStaffChat(user)) {
      staff = true;
    } else {
      state = 0;
      return;
    }
    try {
      final count = await ref.read(chatRepositoryProvider).unread(staff: staff);
      if (ref.mounted) state = count;
    } catch (_) {
      // A badge is a nicety: keep the last count rather than break the shell.
    }
  }
}

final chatUnreadProvider = NotifierProvider<ChatUnreadNotifier, int>(
  ChatUnreadNotifier.new,
);
