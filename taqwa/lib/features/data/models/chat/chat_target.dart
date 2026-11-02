import '../user_model.dart';

/// Which thread a screen talks to: the signed-in parent's own, or, for staff,
/// the thread of parent [parentId].
class ChatTarget {
  final int? parentId;

  const ChatTarget.mine() : parentId = null;
  const ChatTarget.parent(int this.parentId);

  bool get isStaff => parentId != null;

  @override
  bool operator ==(Object other) =>
      other is ChatTarget && other.parentId == parentId;

  @override
  int get hashCode => parentId.hashCode;
}

/// Whether [user] answers parents from the shared inbox. Mirrors the server:
/// admins always, managers only with the chat privilege.
bool canUseStaffChat(UserModel? user) =>
    user != null &&
    (user.role == UserRole.admin ||
        (user.role == UserRole.manager && user.canChat));
