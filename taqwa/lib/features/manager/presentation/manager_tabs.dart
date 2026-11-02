/// Bottom-tab positions in the manager shell that other pages jump to.
///
/// The chat tab exists only for managers with the chat privilege, and it sits
/// before التبريرات, so that tab's index depends on it.
abstract final class ManagerTabs {
  static const chat = 3;

  static int justifications({required bool canChat}) => canChat ? 4 : 3;
}
