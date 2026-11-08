/// A child shown under a parent in the staff inbox.
class ChatChildModel {
  final int id;
  final String fullName;
  final int? halaqaId;
  final String? halaqaName;

  /// Inside the viewer's chat scope. A manager's inbox groups a parent only
  /// under these children's halaqas, never under a sibling's halaqa they do
  /// not manage. True when the server predates the field.
  final bool inScope;

  const ChatChildModel({
    required this.id,
    required this.fullName,
    this.halaqaId,
    this.halaqaName,
    this.inScope = true,
  });

  factory ChatChildModel.fromJson(Map<String, dynamic> json) => ChatChildModel(
    id: (json['id'] as num).toInt(),
    fullName: (json['fullName'] as String?) ?? '',
    halaqaId: (json['halaqaId'] as num?)?.toInt(),
    halaqaName: json['halaqaName'] as String?,
    inScope: (json['inScope'] as bool?) ?? true,
  );
}

/// One parent in the staff inbox or the new-chat picker.
class ChatInboxItemModel {
  final int parentId;
  final String parentName;
  final String? parentAvatar;
  final List<ChatChildModel> children;

  /// Null when no message has been sent yet (the picker lists those too).
  final String? preview;
  final bool? lastFromStaff;
  final DateTime? lastAt;

  /// This staff member's own unread count for the thread.
  final int unread;

  const ChatInboxItemModel({
    required this.parentId,
    required this.parentName,
    this.parentAvatar,
    this.children = const [],
    this.preview,
    this.lastFromStaff,
    this.lastAt,
    this.unread = 0,
  });

  factory ChatInboxItemModel.fromJson(Map<String, dynamic> json) {
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return ChatInboxItemModel(
      parentId: (json['parentId'] as num).toInt(),
      parentName: (json['parentName'] as String?) ?? '',
      parentAvatar: json['parentAvatar'] as String?,
      children: ((json['children'] as List?) ?? const [])
          .map((e) => ChatChildModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      preview: last?['preview'] as String?,
      lastFromStaff: last?['fromStaff'] as bool?,
      lastAt: last == null
          ? null
          : DateTime.parse(last['at'] as String).toLocal(),
      unread: (json['unread'] as num?)?.toInt() ?? 0,
    );
  }

  /// "يوسف · حلقة الفرقان، سارة": the children, for a thread's subtitle.
  String get childrenLabel => children
      .map(
        (c) => c.halaqaName == null
            ? c.fullName
            : '${c.fullName} · ${c.halaqaName}',
      )
      .join('، ');
}
