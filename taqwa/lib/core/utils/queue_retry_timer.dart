import 'dart:async';

/// Retries held attendance on a clock while any is waiting.
///
/// A clock rather than a connectivity listener because the case that matters
/// most has no connectivity event at all: the phone keeps its wifi while the
/// server is down, and only trying again tells the two apart.
class QueueRetryTimer {
  QueueRetryTimer({
    required this.onTick,
    this.interval = const Duration(minutes: 1),
  });

  final Future<void> Function() onTick;
  final Duration interval;
  Timer? _timer;

  /// Call whenever the queue changes. Starting is idempotent, so callers do
  /// not need to know whether a timer is already running.
  void sync({required bool hasPending}) {
    if (!hasPending) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(interval, (_) => onTick());
    }
  }

  void dispose() => sync(hasPending: false);
}
