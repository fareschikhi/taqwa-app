import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/data/models/chat/chat_inbox_item_model.dart';
import 'package:taqwa/features/data/models/chat/chat_message_model.dart';
import 'package:taqwa/features/data/models/chat/chat_page_model.dart';

Map<String, dynamic> _message({Map<String, dynamic> over = const {}}) => {
  'id': 7,
  'mine': false,
  'fromStaff': true,
  'senderName': 'الإدارة',
  'staffSenderName': 'أحمد',
  'body': 'نرجو إرسال سبب الغياب',
  'hasImage': false,
  'edited': true,
  'deleted': false,
  'canEdit': false,
  'canDelete': false,
  'createdAt': '2026-11-02T10:00:00.000Z',
  'updatedAt': '2026-11-02T10:05:00.000Z',
  ...over,
};

void main() {
  test('reads every field of a message', () {
    final m = ChatMessageModel.fromJson(_message());

    expect(m.id, 7);
    expect(m.mine, isFalse);
    expect(m.fromStaff, isTrue);
    expect(m.senderName, 'الإدارة');
    expect(m.staffSenderName, 'أحمد');
    expect(m.body, 'نرجو إرسال سبب الغياب');
    expect(m.edited, isTrue);
    expect(m.createdAt.toUtc(), DateTime.utc(2026, 11, 2, 10));
    expect(m.updatedAt.toUtc(), DateTime.utc(2026, 11, 2, 10, 5));
  });

  test('a parent copy has no staff name', () {
    final json = _message()..remove('staffSenderName');

    expect(ChatMessageModel.fromJson(json).staffSenderName, isNull);
  });

  test('a deleted message has no body', () {
    final m = ChatMessageModel.fromJson(
      _message(over: {'deleted': true, 'body': null}),
    );

    expect(m.deleted, isTrue);
    expect(m.body, isNull);
  });

  test('reads a page with its server time', () {
    final page = ChatPageModel.fromJson({
      'messages': [_message()],
      'serverTime': '2026-11-02T10:06:00.000Z',
      'hasMore': true,
    });

    expect(page.messages.single.id, 7);
    expect(page.serverTime.toUtc(), DateTime.utc(2026, 11, 2, 10, 6));
    expect(page.hasMore, isTrue);
  });

  test('reads an inbox row, with or without a last message', () {
    final row = ChatInboxItemModel.fromJson({
      'parentId': 9,
      'parentName': 'محمد بن علي',
      'parentAvatar': null,
      'children': [
        {'id': 3, 'fullName': 'يوسف', 'halaqaName': 'حلقة الفرقان'},
        {'id': 4, 'fullName': 'سارة', 'halaqaName': null},
      ],
      'lastMessage': {
        'preview': 'كان مريضاً',
        'fromStaff': false,
        'at': '2026-11-02T10:15:00.000Z',
      },
      'unread': 2,
    });

    expect(row.parentId, 9);
    expect(row.children.map((c) => c.halaqaName), ['حلقة الفرقان', null]);
    expect(row.preview, 'كان مريضاً');
    expect(row.unread, 2);

    final empty = ChatInboxItemModel.fromJson({
      'parentId': 9,
      'parentName': 'x',
      'children': [],
      'lastMessage': null,
      'unread': 0,
    });
    expect(empty.preview, isNull);
    expect(empty.lastAt, isNull);
  });
}
