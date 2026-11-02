import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taqwa/features/chat/data/chat_push.dart';
import 'package:taqwa/features/data/models/chat/chat_message_model.dart';
import 'package:taqwa/features/data/models/chat/chat_page_model.dart';
import 'package:taqwa/features/data/models/chat/chat_target.dart';
import 'package:taqwa/features/data/repositories/chat_repository.dart';

ChatMessageModel message({
  int id = 1,
  bool mine = false,
  bool fromStaff = true,
  String senderName = 'الإدارة',
  String? staffSenderName,
  String? body = 'نص الرسالة',
  bool edited = false,
  bool deleted = false,
  bool canEdit = false,
  bool canDelete = false,
}) => ChatMessageModel(
  id: id,
  mine: mine,
  fromStaff: fromStaff,
  senderName: senderName,
  staffSenderName: staffSenderName,
  body: body,
  edited: edited,
  deleted: deleted,
  canEdit: canEdit,
  canDelete: canDelete,
  createdAt: DateTime(2026, 11, 2, 10),
  updatedAt: DateTime(2026, 11, 2, 10),
);

/// A repository that answers from memory and records what was sent.
class FakeChatRepository extends ChatRepository {
  FakeChatRepository({this.messages = const []});

  final List<ChatMessageModel> messages;
  Object? sendError;
  Object? pageError;
  final sent = <String?>[];

  @override
  Future<ChatPageModel> page(
    ChatTarget t, {
    int? beforeId,
    DateTime? since,
  }) async {
    if (pageError != null) throw pageError!;
    return ChatPageModel(
      messages: since == null ? messages : const [],
      serverTime: DateTime(2026, 11, 2, 11),
      hasMore: false,
    );
  }

  @override
  Future<ChatMessageModel> send(
    ChatTarget t, {
    String? body,
    XFile? photo,
  }) async {
    sent.add(body);
    if (sendError != null) throw sendError!;
    return message(id: 100, mine: true, fromStaff: t.isStaff, body: body);
  }

  @override
  Future<void> markRead(ChatTarget t) async {}

  @override
  Future<int> unread({required bool staff}) async => 0;
}

DioException forbidden() => DioException(
  requestOptions: RequestOptions(path: '/chat'),
  response: Response(
    requestOptions: RequestOptions(path: '/chat'),
    statusCode: 403,
    data: {'message': 'غير مصرح لك بهذه المحادثة'},
  ),
);

Widget host(Widget child, {ChatRepository? repo}) => ProviderScope(
  overrides: [
    chatRepositoryProvider.overrideWithValue(repo ?? FakeChatRepository()),
    chatPushesProvider.overrideWithValue(const Stream.empty()),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) => MaterialApp(home: child),
  ),
);
