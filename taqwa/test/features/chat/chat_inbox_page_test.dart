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
    // Once on the thread, once on its halaqa's header.
    expect(find.text('2'), findsNWidgets(2));
  });

  testWidgets('groups threads by halaqa and folds a group on tap', (
    tester,
  ) async {
    ChatInboxItemModel thread(int id, String name, int halaqaId, String h) =>
        ChatInboxItemModel(
          parentId: id,
          parentName: name,
          children: [
            ChatChildModel(
              id: id,
              fullName: 'طالب',
              halaqaId: halaqaId,
              halaqaName: h,
            ),
          ],
        );
    final repo = _InboxRepo([
      thread(1, 'محمد', 4, 'حلقة الفرقان'),
      thread(2, 'أحمد', 7, 'حلقة النور'),
      thread(3, 'خالد', 4, 'حلقة الفرقان'),
    ]);

    await tester.pumpWidget(host(const ChatInboxPage(), repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('حلقة الفرقان'), findsOneWidget);
    expect(find.text('محادثتان'), findsOneWidget);

    await tester.tap(find.text('حلقة الفرقان'));
    await tester.pumpAndSettle();

    // Folding the first band brings the next one into view.
    expect(find.text('محمد'), findsNothing);
    expect(find.text('حلقة النور'), findsOneWidget);
    expect(find.text('أحمد'), findsOneWidget);
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

  // The admin shell has no app bar, so its drawer page must carry the
  // shell's menu button or the admin is stuck on the inbox.
  testWidgets('shows the leading widget it is given', (tester) async {
    await tester.pumpWidget(
      host(
        const ChatInboxPage(leading: Icon(Icons.menu)),
        repo: _InboxRepo([]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('says so when there is no conversation yet', (tester) async {
    await tester.pumpWidget(host(const ChatInboxPage(), repo: _InboxRepo([])));
    await tester.pumpAndSettle();

    expect(find.text('لا توجد محادثات بعد'), findsOneWidget);
    expect(find.text('+ محادثة جديدة مع ولي أمر'), findsOneWidget);
  });
}
