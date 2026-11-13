import 'package:shared_preferences/shared_preferences.dart';

/// Puts [groups] in the user's own halaqa order: the halaqas in [order]
/// first, as they were dragged; the rest after them in the order they came
/// in; the unassigned bucket (a null id) last.
///
/// With no saved order the list comes back untouched, so a screen keeps its
/// own default (by name, or by latest activity in the chat inbox).
List<T> applyHalaqaOrder<T>(
  List<T> groups,
  List<int> order, {
  required int? Function(T group) idOf,
}) {
  if (order.isEmpty) return groups;
  final rank = {for (final (i, id) in order.indexed) id: i};

  final saved = groups.where((g) => rank.containsKey(idOf(g))).toList()
    ..sort((x, y) => rank[idOf(x)]!.compareTo(rank[idOf(y)]!));
  final rest = groups.where((g) {
    final id = idOf(g);
    return id != null && !rank.containsKey(id);
  });
  final unassigned = groups.where((g) => idOf(g) == null);

  return [...saved, ...rest, ...unassigned];
}

/// The saved order after the user re-dragged [reordered], which may be only
/// the halaqas one screen shows (a manager sees just their own). Those
/// halaqas swap among the slots they already held; every halaqa the screen
/// did not show keeps its slot. A halaqa not saved before joins at the end
/// first, then takes part in the swap.
List<int> mergeHalaqaOrder(List<int> saved, List<int> reordered) {
  final moved = reordered.toSet();
  final base = {...saved, ...reordered}.toList();
  var next = 0;
  return [for (final id in base) moved.contains(id) ? reordered[next++] : id];
}

/// Remembers each user's halaqa order on this phone. Keyed by user id, so two
/// accounts signed in on one phone keep their own.
class HalaqaOrderStore {
  const HalaqaOrderStore._();

  static String keyFor(int userId) => 'halaqa_order_$userId';

  /// An empty order (the screens' own default) when nothing is stored or
  /// storage can't be read.
  static Future<List<int>> read(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(keyFor(userId)) ?? const [];
      return raw.map(int.tryParse).whereType<int>().toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> write(int userId, List<int> order) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(keyFor(userId), [
        for (final id in order) '$id',
      ]);
    } catch (_) {
      // Losing it only means the next launch shows the default order.
    }
  }
}
