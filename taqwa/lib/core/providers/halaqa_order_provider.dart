import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taqwa/core/providers/auth_provider.dart';
import 'package:taqwa/core/utils/halaqa_order.dart';

/// The signed-in user's halaqa order, shared by every screen that groups by
/// halaqa: reordering on one screen reorders the others too. Empty until the
/// saved order is read, and for a user who never set one.
class HalaqaOrderNotifier extends Notifier<List<int>> {
  /// Completes once the saved order is in [state], for a screen that must
  /// send it with its very first request (the paged admin roster).
  late Future<void> ready;

  int? _userId;

  @override
  List<int> build() {
    _userId = ref.watch(authProvider.select((s) => s.user?.id));
    ready = _load(_userId);
    return const [];
  }

  Future<void> _load(int? userId) async {
    if (userId == null) return;
    final saved = await HalaqaOrderStore.read(userId);
    if (ref.mounted && _userId == userId) state = saved;
  }

  /// Saves [reordered], the halaqas one screen showed in their new order;
  /// halaqas that screen did not show keep their place.
  Future<void> save(List<int> reordered) async {
    // A save racing the first read would merge into an empty order and then
    // be overwritten by the stale one.
    await ready;
    final userId = _userId;
    if (userId == null || !ref.mounted) return;
    final next = mergeHalaqaOrder(state, reordered);
    state = next;
    await HalaqaOrderStore.write(userId, next);
  }
}

final halaqaOrderProvider = NotifierProvider<HalaqaOrderNotifier, List<int>>(
  HalaqaOrderNotifier.new,
);
