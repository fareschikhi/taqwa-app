import 'package:flutter/widgets.dart';

/// Lets a page inside a bottom-nav shell switch the shell's tab, so a
/// dashboard card can open the tab that lists what it counts.
class ShellTabScope extends InheritedWidget {
  const ShellTabScope({
    super.key,
    required this.selectTab,
    required super.child,
  });

  final ValueChanged<int> selectTab;

  /// Read without registering a dependency: the callback is all a page needs,
  /// and it should not rebuild every time the shell does.
  static ShellTabScope? of(BuildContext context) {
    return context.getInheritedWidgetOfExactType<ShellTabScope>();
  }

  @override
  bool updateShouldNotify(ShellTabScope oldWidget) => false;
}
