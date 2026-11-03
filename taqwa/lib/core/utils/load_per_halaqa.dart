/// Fetches something once per halaqa, all halaqas at the same time.
///
/// [claimed] is the caller's memory of halaqas already asked for. Each new id
/// is claimed *before* any request goes out, so a second call that overlaps
/// this one (the next page of a roster arriving mid-load) skips it instead of
/// asking twice. A halaqa whose fetch fails is released again, so a later
/// call can retry it, and never stops the others: [onLoaded] still runs for
/// every halaqa that answered.
Future<void> loadPerHalaqa<T>({
  required Iterable<int> halaqaIds,
  required Set<int> claimed,
  required Future<T> Function(int halaqaId) fetch,
  required void Function(T result) onLoaded,
}) async {
  final mine = <int>[];
  for (final id in halaqaIds) {
    if (claimed.add(id)) mine.add(id);
  }
  await Future.wait(
    mine.map((id) async {
      try {
        onLoaded(await fetch(id));
      } catch (_) {
        claimed.remove(id);
      }
    }),
  );
}
