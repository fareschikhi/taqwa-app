import 'package:flutter/material.dart';
import '../utils/app_update.dart';
import 'app_text.dart';

/// Checks Play for a newer version when the app starts, and again when it
/// comes back after [recheckAfter], since parents leave it open for days.
///
/// Once the download is done it shows a bar with a restart button. The
/// restart is the parent's choice, so it never happens mid-task.
class AppUpdatePrompt extends StatefulWidget {
  const AppUpdatePrompt({
    super.key,
    required this.child,
    this.api = AppUpdateApi.play,
    this.enabled,
  });

  final Widget child;
  final AppUpdateApi api;

  /// Defaults to [canUseInAppUpdate]; tests turn it on.
  final bool? enabled;

  static const Duration recheckAfter = Duration(hours: 6);

  @override
  State<AppUpdatePrompt> createState() => _AppUpdatePromptState();
}

class _AppUpdatePromptState extends State<AppUpdatePrompt> {
  AppLifecycleListener? _lifecycle;
  DateTime? _lastCheck;
  bool _checking = false;
  // Once a parent says no, or the bar is up, stop asking until next launch.
  bool _done = false;

  @override
  void initState() {
    super.initState();
    if (!(widget.enabled ?? canUseInAppUpdate)) return;
    _lifecycle = AppLifecycleListener(onShow: _onShow);
    // After the first frame, so the messenger is ready for the bar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
    super.dispose();
  }

  void _onShow() {
    final last = _lastCheck;
    if (last != null &&
        DateTime.now().difference(last) < AppUpdatePrompt.recheckAfter) {
      return;
    }
    _check();
  }

  Future<void> _check() async {
    if (_checking || _done) return;
    _checking = true;
    _lastCheck = DateTime.now();
    final outcome = await runFlexibleUpdate(widget.api);
    _checking = false;
    if (!mounted) return;

    switch (outcome) {
      case AppUpdateOutcome.ready:
        _done = true;
        _showRestartBar();
      case AppUpdateOutcome.declined:
        _done = true;
      case AppUpdateOutcome.none:
      case AppUpdateOutcome.failed:
        break;
    }
  }

  void _showRestartBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const AppText('نسخة جديدة من التطبيق جاهزة'),
        // Stays until the parent acts on it; a restart is easy to miss.
        duration: const Duration(days: 1),
        showCloseIcon: true,
        action: SnackBarAction(
          label: 'إعادة التشغيل',
          onPressed: _restart,
        ),
      ),
    );
  }

  Future<void> _restart() async {
    try {
      // Play closes the app, installs the update and opens it again.
      await widget.api.complete();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText('تعذّر تثبيت التحديث، حاول لاحقاً من متجر Play'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
