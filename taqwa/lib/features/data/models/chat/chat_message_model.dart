/// One message in a parent ↔ administration thread, as the API shaped it for
/// the signed-in viewer. A parent's copy of a staff message never carries the
/// staff member's name: the server removed it before sending.
class ChatMessageModel {
  final int id;

  /// On the viewer's side. Staff share one side ("الإدارة").
  final bool mine;
  final bool fromStaff;

  /// "الإدارة" for staff messages, the parent's name for theirs.
  final String senderName;

  /// Staff only: the colleague who wrote a staff message.
  final String? staffSenderName;
  final String? body;
  final bool hasImage;
  final bool edited;
  final bool deleted;
  final bool canEdit;
  final bool canDelete;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatMessageModel({
    required this.id,
    required this.mine,
    required this.fromStaff,
    required this.senderName,
    this.staffSenderName,
    this.body,
    this.hasImage = false,
    this.edited = false,
    this.deleted = false,
    this.canEdit = false,
    this.canDelete = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: (json['id'] as num).toInt(),
      mine: (json['mine'] as bool?) ?? false,
      fromStaff: (json['fromStaff'] as bool?) ?? false,
      senderName: (json['senderName'] as String?) ?? '',
      staffSenderName: json['staffSenderName'] as String?,
      body: json['body'] as String?,
      hasImage: (json['hasImage'] as bool?) ?? false,
      edited: (json['edited'] as bool?) ?? false,
      deleted: (json['deleted'] as bool?) ?? false,
      canEdit: (json['canEdit'] as bool?) ?? false,
      canDelete: (json['canDelete'] as bool?) ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }
}
