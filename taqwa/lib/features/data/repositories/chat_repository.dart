import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/features/data/datasources/chat_remote_datasource.dart';
import 'package:taqwa/features/data/models/chat/chat_inbox_item_model.dart';
import 'package:taqwa/features/data/models/chat/chat_message_model.dart';
import 'package:taqwa/features/data/models/chat/chat_page_model.dart';
import 'package:taqwa/features/data/models/chat/chat_target.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';

/// Overridable in tests, so widgets and providers run without a server.
final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(),
);

class ChatRepository {
  final _ds = ChatRemoteDatasource();

  Future<ChatPageModel> page(ChatTarget t, {int? beforeId, DateTime? since}) =>
      _ds.page(t, beforeId: beforeId, since: since);

  Future<ChatMessageModel> send(ChatTarget t, {String? body, XFile? photo}) =>
      _ds.send(t, body: body, photo: photo);

  Future<void> markRead(ChatTarget t) => _ds.markRead(t);

  Future<ChatMessageModel> edit(int messageId, String body) =>
      _ds.edit(messageId, body);

  Future<ChatMessageModel> delete(int messageId) => _ds.delete(messageId);

  Future<int> unread({required bool staff}) => _ds.unread(staff: staff);

  Future<List<ChatInboxItemModel>> inbox({String? search}) =>
      _ds.inbox(search: search);

  Future<List<ChatInboxItemModel>> pickableParents({String? search}) =>
      _ds.pickableParents(search: search);

  /// Chat photos are private: load this URL with the bearer token header.
  String photoUrl(int messageId) =>
      '${ApiEndpoints.baseUrl}${ApiEndpoints.chat}/photos/$messageId';

  /// True when the server refused because this user lost access (403).
  static bool isForbidden(Object e) =>
      e is DioException && e.response?.statusCode == 403;

  /// A readable Arabic message, the way the other repositories do it.
  static String errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      final msg = data is Map ? data['message'] : null;
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      if (msg is String) return msg;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return 'تعذر الاتصال بالخادم، تحقق من الإنترنت';
      }
    }
    return 'حدث خطأ غير متوقع';
  }
}
