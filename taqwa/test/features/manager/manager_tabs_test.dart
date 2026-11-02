import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/features/manager/presentation/manager_tabs.dart';

void main() {
  // The chat tab sits before التبريرات, so the dashboard's jump to it moves
  // by one when the manager has chat.
  test('justifications is the fifth tab with chat, the fourth without', () {
    expect(ManagerTabs.justifications(canChat: true), 4);
    expect(ManagerTabs.justifications(canChat: false), 3);
  });

  test('chat is the fourth tab', () {
    expect(ManagerTabs.chat, 3);
  });
}
