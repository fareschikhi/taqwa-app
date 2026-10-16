import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/save_gate.dart';

// testWidgets runs on a fake clock, so the grace period passes on pump.
void main() {
  testWidgets('open until a refresh begins', (tester) async {
    final gate = SaveGate();
    var passed = false;

    gate.ready.then((_) => passed = true);
    await tester.pump();

    expect(gate.waiting, isFalse);
    expect(passed, isTrue);
    gate.dispose();
  });

  testWidgets('a save waits for the server answer', (tester) async {
    final gate = SaveGate();
    var passed = false;

    gate.begin();
    gate.ready.then((_) => passed = true);
    await tester.pump(const Duration(seconds: 2));
    expect(gate.waiting, isTrue);
    expect(passed, isFalse);

    gate.end();
    await tester.pump();
    expect(gate.waiting, isFalse);
    expect(passed, isTrue);
    gate.dispose();
  });

  testWidgets('with no answer, it opens after five seconds', (tester) async {
    // No signal can hang a request for 30s; the teacher must not wait that
    // long to save, and a failed save is held on the phone anyway.
    final gate = SaveGate();
    var passed = false;

    gate.begin();
    gate.ready.then((_) => passed = true);
    await tester.pump(const Duration(milliseconds: 4999));
    expect(passed, isFalse);

    await tester.pump(const Duration(milliseconds: 1));
    expect(gate.waiting, isFalse);
    expect(passed, isTrue);
    gate.dispose();
  });

  testWidgets('a second refresh closes it again', (tester) async {
    final gate = SaveGate();

    gate.begin();
    gate.end();
    gate.begin();

    expect(gate.waiting, isTrue);
    gate.end();
    gate.dispose();
  });

  testWidgets('tells the page whenever it opens or closes', (tester) async {
    var changes = 0;
    final gate = SaveGate(onChange: () => changes++);

    gate.begin();
    gate.end();
    gate.begin();
    await tester.pump(const Duration(seconds: 5));

    expect(changes, 4);
    gate.dispose();
  });
}
