import 'dart:async';

/// Holds saves back while a screen drawn from the phone's copy waits for the
/// server, so marks taken against old data cannot overwrite newer rows.
///
/// The hold has a limit. Without signal a request can hang for the full
/// network timeout, and a save made then fails into the offline queue
/// anyway, so making the teacher wait longer than [grace] protects nothing.
class SaveGate {
  SaveGate({this.grace = const Duration(seconds: 5), this.onChange});

  final Duration grace;

  /// Called whenever [waiting] flips, so the page can redraw its button.
  final void Function()? onChange;

  Completer<void>? _pending;
  Timer? _timer;

  bool get waiting => _pending != null;

  /// Completes once saving is safe; immediately if nothing is being waited on.
  Future<void> get ready => _pending?.future ?? Future.value();

  void begin() {
    if (_pending != null) return;
    _pending = Completer<void>();
    _timer = Timer(grace, end);
    onChange?.call();
  }

  void end() {
    final pending = _pending;
    if (pending == null) return;
    _timer?.cancel();
    _timer = null;
    _pending = null;
    pending.complete();
    onChange?.call();
  }

  /// Releases anyone waiting without calling [onChange]: the page calling
  /// this is going away and must not be asked to redraw.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _pending?.complete();
    _pending = null;
  }
}
