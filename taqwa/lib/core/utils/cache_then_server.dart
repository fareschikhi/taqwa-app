/// One value for a screen to show, and whether it is the phone's copy or the
/// server's own answer.
class CacheUpdate<T> {
  const CacheUpdate(this.value, {required this.fromCache});

  final T value;
  final bool fromCache;
}

/// Shows the phone's copy at once, then the server's answer when it lands.
///
/// The server's answer is always applied, never compared against the copy
/// first: rebuilding with equal data draws nothing new, so a comparison would
/// only add a place for the two to disagree.
///
/// A failed fetch after a copy was shown ends the stream quietly, since the
/// screen already has something to show. A stream whose last update is still
/// [CacheUpdate.fromCache] therefore means "offline". With no copy at all,
/// the failure is the stream's error.
Stream<CacheUpdate<T>> cacheThenServer<T>({
  required Future<T?> Function() readCache,
  required Future<T> Function() fetch,
  required Future<void> Function(T value) writeCache,
}) async* {
  T? cached;
  try {
    cached = await readCache();
  } catch (_) {
    // An unreadable copy is the same as none; the server still answers.
  }
  if (cached != null) yield CacheUpdate(cached, fromCache: true);

  final T fresh;
  try {
    fresh = await fetch();
  } catch (_) {
    if (cached == null) rethrow;
    return;
  }
  yield CacheUpdate(fresh, fromCache: false);

  try {
    await writeCache(fresh);
  } catch (_) {
    // A copy that failed to save only costs the next open its head start.
  }
}
