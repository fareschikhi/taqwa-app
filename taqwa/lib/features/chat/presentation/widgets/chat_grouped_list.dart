import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/providers/halaqa_order_provider.dart';
import '../../../../core/utils/halaqa_order.dart';
import '../../../../core/widgets/halaqa_order_sheet.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/halaqa_group_section.dart';
import '../../../data/models/chat/chat_inbox_item_model.dart';
import '../chat_grouping.dart';
import 'chat_inbox_tile.dart';

/// "محادثة واحدة", "محادثتان", "3 محادثات", "11 محادثة".
String chatCountLabel(int count) {
  if (count == 1) return 'محادثة واحدة';
  if (count == 2) return 'محادثتان';
  if (count <= 10) return '$count محادثات';
  return '$count محادثة';
}

/// "ولي أمر واحد", "وليّا أمر", "3 أولياء أمور", "11 ولي أمر".
String parentCountLabel(int count) {
  if (count == 1) return 'ولي أمر واحد';
  if (count == 2) return 'وليّا أمر';
  if (count <= 10) return '$count أولياء أمور';
  return '$count ولي أمر';
}

/// The staff inbox or picker as foldable halaqa bands. It keeps which bands
/// the user closed across reloads, so a new message doesn't reopen them.
class ChatGroupedList extends ConsumerStatefulWidget {
  const ChatGroupedList({
    super.key,
    required this.items,
    required this.onTap,
    required this.countLabel,
    this.byName = false,
  });

  final List<ChatInboxItemModel> items;
  final void Function(ChatInboxItemModel item) onTap;
  final String Function(int count) countLabel;

  /// Sort bands by halaqa name (the picker) instead of by latest activity.
  final bool byName;

  @override
  ConsumerState<ChatGroupedList> createState() => _ChatGroupedListState();
}

class _ChatGroupedListState extends ConsumerState<ChatGroupedList> {
  final Set<int?> _collapsed = {};

  @override
  Widget build(BuildContext context) {
    // A saved order wins over latest-activity order: the user asked for it.
    final groups = applyHalaqaOrder(
      groupChatsByHalaqa(widget.items, byName: widget.byName),
      ref.watch(halaqaOrderProvider),
      idOf: (g) => g.halaqaId,
    );
    final halaqas = reorderableHalaqas<ChatHalaqaGroup>(
      groups,
      idOf: (g) => g.halaqaId,
      nameOf: (g) => g.name,
    );

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 24.h),
      itemCount: groups.length,
      separatorBuilder: (_, _) => SizedBox(height: 20.h),
      itemBuilder: (_, i) {
        final group = groups[i];
        return HalaqaGroupSection(
          title: group.name,
          count: group.items.length,
          countLabel: widget.countLabel(group.items.length),
          badge: group.unread,
          isUnassigned: group.isUnassigned,
          isExpanded: !_collapsed.contains(group.halaqaId),
          onReorder: halaqas == null
              ? null
              : () => reorderHalaqas(context, ref, halaqas),
          onToggle: () => setState(() {
            if (!_collapsed.remove(group.halaqaId)) {
              _collapsed.add(group.halaqaId);
            }
          }),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              child: Column(
                children: [
                  for (final item in group.items)
                    ChatInboxTile(item: item, onTap: () => widget.onTap(item)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
