import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/student_grouping.dart';
import 'package:taqwa/features/chat/presentation/chat_grouping.dart';
import 'package:taqwa/features/data/models/chat/chat_inbox_item_model.dart';

ChatChildModel child(int id, int? halaqaId, {bool inScope = true}) =>
    ChatChildModel(
      id: id,
      fullName: 'طالب $id',
      halaqaId: halaqaId,
      halaqaName: halaqaId == null ? null : 'حلقة $halaqaId',
      inScope: inScope,
    );

ChatInboxItemModel parent(
  int id,
  List<ChatChildModel> children, {
  int unread = 0,
}) => ChatInboxItemModel(
  parentId: id,
  parentName: 'ولي $id',
  children: children,
  unread: unread,
);

void main() {
  test('keeps the inbox order: the latest thread brings its halaqa up', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, 7)]),
      parent(2, [child(2, 4)]),
      parent(3, [child(3, 7)]),
    ]);

    expect(groups.map((g) => g.name), ['حلقة 7', 'حلقة 4']);
    expect(groups.first.items.map((i) => i.parentId), [1, 3]);
  });

  test('lists a parent under each halaqa of their in-scope children', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, 4), child(2, 7), child(3, 4)]),
    ]);

    expect(groups.map((g) => g.halaqaId), [4, 7]);
    expect(groups.every((g) => g.items.length == 1), isTrue);
  });

  // A manager of halaqa 4 must not get a band for a sibling's halaqa 7.
  test('adds no group for a child outside the viewer scope', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, 4), child(2, 7, inScope: false)]),
    ]);

    expect(groups.map((g) => g.halaqaId), [4]);
  });

  test('puts children in no halaqa under the unassigned group', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, null)]),
    ]);

    expect(groups.single.isUnassigned, isTrue);
    expect(groups.single.name, unassignedHalaqaLabel);
  });

  test('byName sorts by halaqa name with unassigned last', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, null)]),
      parent(2, [child(2, 7)]),
      parent(3, [child(3, 4)]),
    ], byName: true);

    expect(groups.map((g) => g.halaqaId), [4, 7, null]);
  });

  test('sums unread per group', () {
    final groups = groupChatsByHalaqa([
      parent(1, [child(1, 4)], unread: 2),
      parent(2, [child(2, 4)], unread: 3),
    ]);

    expect(groups.single.unread, 5);
  });
}
