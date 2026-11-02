import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/chat/presentation/pages/chat_inbox_page.dart';
import 'package:taqwa/features/data/models/chat/chat_inbox_item_model.dart';

import 'chat_test_utils.dart';

class _InboxRepo extends FakeChatRepository {
  _InboxRepo(this.rows);
  final List<ChatInboxItemModel> rows;

  @override
  Future<List<ChatInboxItemModel>> inbox({String? search}) async => rows;
}

void main() {
  testWidgets('lists threads with their preview and unread count', (
    tester,
  ) async {
    final repo = _InboxRepo([
      ChatInboxItemModel(
        parentId: 9,
        parentName: 'محمد بن علي',
        children: const [
          ChatChildModel(id: 3, fullName: 'يوسف', halaqaName: 'حلقة الفرقان'),
        ],
        preview: 'كان مريضاً',
        lastFromStaff: false,
        lastAt: DateTime(2026, 11, 2, 10, 15),
        unread: 2,
      ),
    ]);

    await tester.pumpWidget(host(const ChatInboxPage(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('محمد بن علي'), findsOneWidget);
    expect(find.text('كان مريضاً'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  // A manager opens the inbox from the dashboard, on top of it; the admin
  // has it as a drawer page, where there is nothing to go back to.
  testWidgets('offers a way back only when opened on top of a page', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ChatInboxPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
        repo: _InboxRepo([]),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ChatInboxPage), findsNothing);

    await tester.pumpWidget(host(const ChatInboxPage(), repo: _InboxRepo([])));
    await tester.pumpAndSettle();
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('says so when there is no conversation yet', (tester) async {
    await tester.pumpWidget(host(const ChatInboxPage(), repo: _InboxRepo([])));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
    expect(find.text('+ محادثة جديدة مع ولي أمر'), findsOneWidget);
  });
}
