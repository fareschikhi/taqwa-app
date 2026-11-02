import 'chat_message_model.dart';

/// A slice of a thread, oldest first. [serverTime] is what the next poll
/// sends back as `since`, so it sees new, edited and deleted messages.
class ChatPageModel {
  final List<ChatMessageModel> messages;
  final DateTime serverTime;
  final bool hasMore;

  const ChatPageModel({
    required this.messages,
    required this.serverTime,
    required this.hasMore,
  });

  factory ChatPageModel.fromJson(Map<String, dynamic> json) {
    return ChatPageModel(
      messages: (json['messages'] as List)
          .map((e) => ChatMessageModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      serverTime: DateTime.parse(json['serverTime'] as String),
      hasMore: (json['hasMore'] as bool?) ?? false,
    );
  }
}
