import '../../../core/utils/student_grouping.dart';
import '../../data/models/chat/chat_inbox_item_model.dart';

/// One halaqa's slice of the staff inbox or picker. [halaqaId] is null for
/// parents whose in-scope children are in no halaqa yet.
class ChatHalaqaGroup {
  const ChatHalaqaGroup({
    required this.halaqaId,
    required this.name,
    required this.items,
  });

  final int? halaqaId;
  final String name;
  final List<ChatInboxItemModel> items;

  bool get isUnassigned => halaqaId == null;

  /// This staff member's unread messages across the group.
  int get unread => items.fold(0, (sum, item) => sum + item.unread);
}

/// Splits [items] into one group per halaqa of their in-scope children.
///
/// A parent with children in two halaqas the viewer covers shows in both
/// groups: a manager looking through one halaqa must still find them. A
/// sibling outside the viewer's scope adds no group.
///
/// Within a group the caller's order is kept (most recent first for the
/// inbox). With [byName] the groups are sorted by halaqa name, unassigned
/// last; otherwise they keep the order of their first item, so the group
/// with the latest message rises to the top like a thread does.
List<ChatHalaqaGroup> groupChatsByHalaqa(
  List<ChatInboxItemModel> items, {
  bool byName = false,
}) {
  final groups = <int?, ChatHalaqaGroup>{};

  for (final item in items) {
    final inScope = item.children.where((c) => c.inScope).toList();
    // Ids only: two children in the same halaqa put the parent there once.
    final keys = inScope.isEmpty
        ? <int?>{null}
        : inScope.map((c) => c.halaqaId).toSet();

    for (final key in keys) {
      final name = key == null
          ? unassignedHalaqaLabel
          : inScope.firstWhere((c) => c.halaqaId == key).halaqaName ??
                unassignedHalaqaLabel;
      groups
          .putIfAbsent(
            key,
            () => ChatHalaqaGroup(halaqaId: key, name: name, items: []),
          )
          .items
          .add(item);
    }
  }

  final result = groups.values.toList();
  if (byName) {
    result.sort((a, b) {
      if (a.isUnassigned != b.isUnassigned) return a.isUnassigned ? 1 : -1;
      return a.name.compareTo(b.name);
    });
  }
  return result;
}
