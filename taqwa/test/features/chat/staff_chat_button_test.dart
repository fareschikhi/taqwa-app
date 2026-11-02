import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/providers/chat_unread_provider.dart';
import 'package:taqwa/features/chat/data/chat_push.dart';
import 'package:taqwa/features/chat/presentation/pages/chat_inbox_page.dart';
import 'package:taqwa/features/chat/presentation/widgets/staff_chat_button.dart';
import 'package:taqwa/features/data/repositories/chat_repository.dart';

import 'chat_test_utils.dart';

class _FixedUnread extends ChatUnreadNotifier {
  _FixedUnread(this.count);
  final int count;

  @override
  int build() => count;

  @override
  Future<void> refresh() async {}
}

Widget _host(int unread) => ProviderScope(
  overrides: [
    chatUnreadProvider.overrideWith(() => _FixedUnread(unread)),
    chatRepositoryProvider.overrideWithValue(FakeChatRepository()),
    chatPushesProvider.overrideWithValue(const Stream.empty()),
  ],
  child: ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, _) =>
        const MaterialApp(home: Scaffold(body: Center(child: StaffChatButton()))),
  ),
);

void main() {
  // A manager's chat lives in the dashboard's top bar, not a sixth bottom
  // tab, so this button is the whole way in and must carry the unread state.
  testWidgets('shows a dot while a parent message is unread', (tester) async {
    await tester.pumpWidget(_host(3));

    expect(find.byKey(const Key('chat-unread-dot')), findsOneWidget);
    expect(find.bySemanticsLabel('المحادثات، رسائل جديدة'), findsOneWidget);
  });

  testWidgets('hides the dot when everything is read', (tester) async {
    await tester.pumpWidget(_host(0));

    expect(find.byKey(const Key('chat-unread-dot')), findsNothing);
    expect(find.bySemanticsLabel('المحادثات'), findsOneWidget);
  });

  testWidgets('opens the inbox', (tester) async {
    await tester.pumpWidget(_host(0));
    await tester.tap(find.byType(StaffChatButton));
    await tester.pumpAndSettle();

    expect(find.byType(ChatInboxPage), findsOneWidget);
  });
}
