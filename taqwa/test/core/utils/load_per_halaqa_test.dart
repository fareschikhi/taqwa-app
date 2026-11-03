import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/load_per_halaqa.dart';

void main() {
  // A roster calls this again whenever a page of students arrives, often
  // before the previous call has finished. A halaqa already asked for must
  // not be asked again.
  test('overlapping loads fetch each halaqa once', () async {
    final calls = <int>[];
    final gate = Completer<void>();
    final claimed = <int>{};
    Future<int> fetch(int id) async {
      calls.add(id);
      await gate.future;
      return id;
    }

    final first = loadPerHalaqa(
      halaqaIds: [1, 2],
      claimed: claimed,
      fetch: fetch,
      onLoaded: (_) {},
    );
    final second = loadPerHalaqa(
      halaqaIds: [1, 2, 3],
      claimed: claimed,
      fetch: fetch,
      onLoaded: (_) {},
    );
    gate.complete();
    await Future.wait([first, second]);

    expect(calls..sort(), [1, 2, 3]);
  });

  test('fetches the halaqas side by side, not one after another', () async {
    final started = <int>[];
    final gate = Completer<void>();
    final done = loadPerHalaqa(
      halaqaIds: [1, 2, 3],
      claimed: {},
      fetch: (id) async {
        started.add(id);
        await gate.future;
        return id;
      },
      onLoaded: (_) {},
    );
    await Future<void>.delayed(Duration.zero);

    expect(started, hasLength(3));
    gate.complete();
    await done;
  });

  // One halaqa refusing must not hide the others, and must stay retryable.
  test('a failing halaqa is released and the rest still load', () async {
    final claimed = <int>{};
    final loaded = <int>[];
    await loadPerHalaqa(
      halaqaIds: [1, 2],
      claimed: claimed,
      fetch: (id) async => id == 1 ? throw Exception('403') : id,
      onLoaded: loaded.add,
    );

    expect(loaded, [2]);
    expect(claimed, {2});
  });
}
