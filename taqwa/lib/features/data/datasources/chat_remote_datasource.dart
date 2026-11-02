import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/features/data/models/chat/chat_inbox_item_model.dart';
import 'package:taqwa/features/data/models/chat/chat_message_model.dart';
import 'package:taqwa/features/data/models/chat/chat_page_model.dart';
import 'package:taqwa/features/data/models/chat/chat_target.dart';
import 'package:taqwa/features/data/network/api_endpoints.dart';
import 'package:taqwa/features/data/network/dio_client.dart';

class ChatRemoteDatasource {
  Dio get _dio => DioClient.instance;

  static const _base = ApiEndpoints.chat;

  String _thread(ChatTarget t) =>
      t.isStaff ? '$_base/parents/${t.parentId}' : '$_base/me';

  Future<ChatPageModel> page(
    ChatTarget t, {
    int? beforeId,
    DateTime? since,
  }) async {
    final res = await _dio.get(
      '${_thread(t)}/messages',
      queryParameters: {
        if (beforeId != null) 'before': beforeId,
        if (since != null) 'since': since.toUtc().toIso8601String(),
      },
    );
    return ChatPageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChatMessageModel> send(
    ChatTarget t, {
    String? body,
    XFile? photo,
  }) async {
    final Object data;
    Options? options;
    if (photo == null) {
      data = {'body': body};
    } else {
      final name = photo.name.isNotEmpty ? photo.name : 'photo.jpg';
      data = FormData.fromMap({
        if (body != null) 'body': body,
        // Dio labels raw bytes application/octet-stream, which the API
        // refuses; the API then checks the real bytes against this type.
        'photo': MultipartFile.fromBytes(
          await photo.readAsBytes(),
          filename: name,
          contentType: DioMediaType.parse(_mimeFor(name)),
        ),
      });
      options = Options(
        contentType: Headers.multipartFormDataContentType,
        // Photos take longer than the client's default timeouts.
        sendTimeout: const Duration(seconds: 60),
        receiveTimeout: const Duration(seconds: 60),
      );
    }
    final res = await _dio.post(
      '${_thread(t)}/messages',
      data: data,
      options: options,
    );
    return ChatMessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> markRead(ChatTarget t) => _dio.post('${_thread(t)}/read');

  Future<ChatMessageModel> edit(int id, String body) async {
    final res = await _dio.patch('$_base/messages/$id', data: {'body': body});
    return ChatMessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ChatMessageModel> delete(int id) async {
    final res = await _dio.delete('$_base/messages/$id');
    return ChatMessageModel.fromJson(res.data as Map<String, dynamic>);
  }

  Future<int> unread({required bool staff}) async {
    final res = await _dio.get(
      staff ? '$_base/conversations/unread' : '$_base/me/unread',
    );
    return ((res.data as Map<String, dynamic>)['count'] as num).toInt();
  }

  Future<List<ChatInboxItemModel>> inbox({String? search}) =>
      _list('$_base/conversations', search);

  Future<List<ChatInboxItemModel>> pickableParents({String? search}) =>
      _list('$_base/parents', search);

  Future<List<ChatInboxItemModel>> _list(String path, String? search) async {
    final term = search?.trim() ?? '';
    final res = await _dio.get(
      path,
      queryParameters: {if (term.isNotEmpty) 'search': term},
    );
    return (res.data as List)
        .map((e) => ChatInboxItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String _mimeFor(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}
