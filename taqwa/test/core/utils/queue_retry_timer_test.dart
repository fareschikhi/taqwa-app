import 'package:flutter_test/flutter_test.dart';
import 'package:taqwa/core/utils/queue_retry_timer.dart';

// testWidgets runs in a fake clock, so a minute passes on tester.pump rather
// than on the wall.
void main() {
  testWidgets('retries every minute while marks are waiting', (tester) async {
    var ticks = 0;
    final timer = QueueRetryTimer(onTick: () async => ticks++);

    timer.sync(hasPending: true);
    await tester.pump(const Duration(seconds: 59));
    expect(ticks, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(ticks, 1);

    await tester.pump(const Duration(minutes: 1));
    expect(ticks, 2);

    timer.dispose();
  });

  testWidgets('stops once the queue is empty', (tester) async {
    var ticks = 0;
    final timer = QueueRetryTimer(onTick: () async => ticks++);

    timer.sync(hasPending: true);
    timer.sync(hasPending: false);
    await tester.pump(const Duration(minutes: 5));

    expect(ticks, 0);
    timer.dispose();
  });

  testWidgets('syncing again does not stack a second timer', (tester) async {
    // Every enqueue syncs, so a teacher who fails three saves in a row must
    // still get one retry a minute, not three.
    var ticks = 0;
    final timer = QueueRetryTimer(onTick: () async => ticks++);

    timer.sync(hasPending: true);
    timer.sync(hasPending: true);
    timer.sync(hasPending: true);
    await tester.pump(const Duration(minutes: 1));

    expect(ticks, 1);
    timer.dispose();
  });

  testWidgets('nothing fires after dispose', (tester) async {
    var ticks = 0;
    final timer = QueueRetryTimer(onTick: () async => ticks++);

    timer.sync(hasPending: true);
    timer.dispose();
    await tester.pump(const Duration(minutes: 5));

    expect(ticks, 0);
  });
}
