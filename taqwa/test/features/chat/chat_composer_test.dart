import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/chat/presentation/widgets/chat_composer.dart';

import 'chat_test_utils.dart';

void main() {
  IconButton sendButton(WidgetTester tester) =>
      tester.widget<IconButton>(find.byKey(const Key('chat-send')));

  testWidgets('send is disabled while empty and while sending', (tester) async {
    final pending = Completer<bool>();
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ChatComposer(
            hint: 'اكتب رسالة',
            onSend: (_, _) => pending.future,
          ),
        ),
      ),
    );

    expect(sendButton(tester).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'السلام عليكم');
    await tester.pump();
    expect(sendButton(tester).onPressed, isNotNull);

    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pump();
    // A second tap while the first send is in flight would duplicate it.
    expect(sendButton(tester).onPressed, isNull);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('السلام عليكم'), findsNothing);
  });

  testWidgets('keeps the text when the send fails', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ChatComposer(hint: 'اكتب رسالة', onSend: (_, _) async => false),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'كان مريضاً');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat-send')));
    await tester.pumpAndSettle();

    expect(find.text('كان مريضاً'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNotNull);
  });
}
