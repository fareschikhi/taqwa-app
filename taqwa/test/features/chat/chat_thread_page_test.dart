import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/chat/presentation/pages/chat_thread_page.dart';
import 'package:taqwa/features/data/models/chat/chat_target.dart';

import 'chat_test_utils.dart';

void main() {
  testWidgets('shows the thread under the الإدارة title', (tester) async {
    final repo = FakeChatRepository(
      messages: [message(body: 'نرجو إرسال سبب الغياب')],
    );

    await tester.pumpWidget(
      host(
        const ChatThreadPage(target: ChatTarget.mine(), title: 'الإدارة'),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('نرجو إرسال سبب الغياب'), findsOneWidget);
    expect(find.text('الإدارة'), findsWidgets);
  });

  testWidgets('a failed send shows why and keeps the text', (tester) async {
    final repo = FakeChatRepository()..sendError = Exception('offline');

    await tester.pumpWidget(
      host(
        const ChatThreadPage(target: ChatTarget.mine(), title: 'الإدارة'),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'كان مريضاً');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('كان مريضاً'), findsOneWidget);
  });

  testWidgets('leaves the thread when access is gone', (tester) async {
    final repo = FakeChatRepository()..pageError = forbidden();

    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ChatThreadPage(
                      target: ChatTarget.parent(9),
                      title: 'محمد',
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        repo: repo,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(ChatThreadPage), findsNothing);
    expect(find.text('لم تعد تملك صلاحية هذه المحادثة'), findsOneWidget);
  });

  // A deactivated parent's history stays readable; only sending is refused,
  // with 409, which must not throw staff out like a lost-access 403.
  testWidgets('a refused reply keeps staff in the thread with their text', (
    tester,
  ) async {
    final repo = FakeChatRepository()
      ..sendError = DioException(
        requestOptions: RequestOptions(path: '/chat'),
        response: Response(
          requestOptions: RequestOptions(path: '/chat'),
          statusCode: 409,
          data: {'message': 'refused'},
        ),
      );

    await tester.pumpWidget(
      host(
        const ChatThreadPage(target: ChatTarget.parent(9), title: 'x'),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'hello');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(find.byType(ChatThreadPage), findsOneWidget);
    expect(find.text('refused'), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });
}
