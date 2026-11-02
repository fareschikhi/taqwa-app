import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/chat_unread_provider.dart';
import 'package:taqwa/features/parent/presentation/widgets/parent_chat_button.dart';

class _FixedUnread extends ChatUnreadNotifier {
  _FixedUnread(this.count);
  final int count;

  @override
  int build() => count;

  @override
  Future<void> refresh() async {}
}

Widget _host(int unread) => ProviderScope(
  overrides: [chatUnreadProvider.overrideWith(() => _FixedUnread(unread))],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) =>
        const MaterialApp(home: Scaffold(body: ParentChatButton())),
  ),
);

void main() {
  testWidgets('shows a dot while a staff message is unread', (tester) async {
    await tester.pumpWidget(_host(2));

    expect(find.byKey(const Key('chat-unread-dot')), findsOneWidget);
    expect(find.bySemanticsLabel('محادثة الإدارة، رسائل جديدة'), findsOneWidget);
  });

  testWidgets('hides the dot when everything is read', (tester) async {
    await tester.pumpWidget(_host(0));

    expect(find.byKey(const Key('chat-unread-dot')), findsNothing);
    expect(find.bySemanticsLabel('محادثة الإدارة'), findsOneWidget);
  });
}
