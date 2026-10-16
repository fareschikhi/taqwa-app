import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/cache_then_server.dart';

void main() {
  test('the saved copy comes first, then the server answer', () async {
    final written = <String>[];

    final updates = await cacheThenServer<String>(
      readCache: () async => 'old',
      fetch: () async => 'new',
      writeCache: (v) async => written.add(v),
    ).toList();

    expect(updates.map((u) => (u.value, u.fromCache)), [
      ('old', true),
      ('new', false),
    ]);
    expect(written, ['new']);
  });

  test('with nothing saved, only the server answer arrives', () async {
    final updates = await cacheThenServer<String>(
      readCache: () async => null,
      fetch: () async => 'new',
      writeCache: (_) async {},
    ).toList();

    expect(updates.map((u) => u.value), ['new']);
  });

  test('a failed fetch after a saved copy ends quietly', () async {
    // The teacher already has a list, so an error would only be noise; the
    // stream ending on a cached update is how the page learns it is offline.
    final updates = await cacheThenServer<String>(
      readCache: () async => 'old',
      fetch: () async => throw Exception('server down'),
      writeCache: (_) async {},
    ).toList();

    expect(updates.map((u) => (u.value, u.fromCache)), [('old', true)]);
  });

  test('a failed fetch with nothing saved is an error', () async {
    final stream = cacheThenServer<String>(
      readCache: () async => null,
      fetch: () async => throw Exception('server down'),
      writeCache: (_) async {},
    );

    await expectLater(stream, emitsError(isA<Exception>()));
  });

  test('an unreadable copy falls through to the server', () async {
    final updates = await cacheThenServer<String>(
      readCache: () async => throw const FormatException(),
      fetch: () async => 'new',
      writeCache: (_) async {},
    ).toList();

    expect(updates.map((u) => u.value), ['new']);
  });

  test('a copy that fails to save does not hide the server answer', () async {
    final updates = await cacheThenServer<String>(
      readCache: () async => null,
      fetch: () async => 'new',
      writeCache: (_) async => throw Exception('disk full'),
    ).toList();

    expect(updates.map((u) => u.value), ['new']);
  });
}
