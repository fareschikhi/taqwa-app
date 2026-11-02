import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/chat/presentation/widgets/chat_bubble.dart';

import 'chat_test_utils.dart';

void main() {
  testWidgets('shows the colleague name only in the staff view', (
    tester,
  ) async {
    final m = message(mine: true, staffSenderName: 'أحمد');

    await tester.pumpWidget(
      host(Scaffold(body: ChatBubble(message: m, staffView: true))),
    );
    expect(find.text('أحمد'), findsOneWidget);

    await tester.pumpWidget(
      host(Scaffold(body: ChatBubble(message: m, staffView: false))),
    );
    expect(find.text('أحمد'), findsNothing);
  });

  testWidgets('a deleted message shows the placeholder and offers no actions', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ChatBubble(
            message: message(deleted: true, body: null),
            staffView: false,
            onLongPress: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('تم حذف هذه الرسالة'), findsOneWidget);
    await tester.longPress(find.byType(ChatBubble));
    expect(pressed, isFalse);
  });

  testWidgets('an edited message says so', (tester) async {
    await tester.pumpWidget(
      host(
        Scaffold(
          body: ChatBubble(
            message: message(body: 'مصحح', edited: true),
            staffView: false,
          ),
        ),
      ),
    );

    expect(find.textContaining('معدّلة'), findsOneWidget);
  });
}
