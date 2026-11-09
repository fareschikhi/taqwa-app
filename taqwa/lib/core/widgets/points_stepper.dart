import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/points_format.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/points_balance_card.dart';
import 'package:taqwa/features/data/repositories/points_repository.dart';

/// Quick − / + for someone's points, one point per tap.
///
/// Taps are batched: each one moves the number on screen at once, and only
/// after [delay] without a tap is the sum sent through [onCommit] — so five
/// taps make one history line of +5, not five lines of +1. Taps made while a
/// batch is being saved start the next batch.
///
/// Leaving the page before [delay] runs out still saves what was tapped.
class PointsStepper extends StatefulWidget {
  const PointsStepper({
    super.key,
    required this.total,
    required this.onCommit,
    this.stepDelay = const Duration(milliseconds: 1500),
  });

  /// The server's total; the preview is drawn from it.
  final num total;

  /// Saves one signed batch (never zero). Should finish only once [total] is
  /// fresh, so the preview does not jump back for a frame. Throwing drops
  /// the batch and shows why.
  final Future<void> Function(num delta) onCommit;

  final Duration stepDelay;

  /// The server takes at most this much in one entry.
  static const maxBatch = 1000;

  @override
  State<PointsStepper> createState() => _PointsStepperState();
}

class _PointsStepperState extends State<PointsStepper> {
  /// Tapped but not sent yet.
  num _pending = 0;

  /// Sent, waiting for the server.
  num _saving = 0;

  Timer? _timer;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Kept for dispose, when the context can no longer be read.
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Back pressed inside the delay: the taps are still the user's intent.
    if (_pending != 0) unawaited(_send(_pending));
    super.dispose();
  }

  void _tap(int step) {
    setState(() => _pending += step);
    _timer?.cancel();
    _timer = Timer(widget.stepDelay, _flush);
  }

  Future<void> _flush() async {
    _timer = null;
    // One batch at a time: the one in flight calls back here when it lands.
    if (_pending == 0 || _saving != 0) return;

    final delta = _pending;
    setState(() {
      _saving = delta;
      _pending = 0;
    });
    await _send(delta);
    if (!mounted) return;
    setState(() => _saving = 0);
    if (_pending != 0 && _timer == null) unawaited(_flush());
  }

  Future<void> _send(num delta) async {
    try {
      await widget.onCommit(delta);
    } catch (e) {
      _messenger?.showSnackBar(
        SnackBar(
          content: AppText(
            'لم يُحفظ التعديل: ${PointsRepository.errorMessage(e)}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final change = _pending + _saving;
    final busy = _saving != 0;

    return Container(
      padding: EdgeInsets.all(8.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          _StepButton(
            icon: Icons.remove,
            tooltip: 'خصم نقطة',
            color: AppColors.error,
            onTap: change - 1 < -PointsStepper.maxBatch ? null : () => _tap(-1),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: change == 0
                  ? AppText(
                      'تعديل سريع',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.labelMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    )
                  : _buildPreview(change, busy),
            ),
          ),
          _StepButton(
            icon: Icons.add,
            tooltip: 'إضافة نقطة',
            color: AppColors.primary,
            onTap: change + 1 > PointsStepper.maxBatch ? null : () => _tap(1),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(num change, bool busy) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppText(
          formatSignedPoints(change),
          style: AppTextStyles.headlineSm.copyWith(
            color: pointsColor(change),
            fontWeight: FontWeight.w700,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy) ...[
              SizedBox(
                width: 12.w,
                height: 12.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              SizedBox(width: 6.w),
            ],
            AppText(
              '${_trimmed(widget.total)} → ${_trimmed(widget.total + change)}',
              style: AppTextStyles.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// A total without its unit, for the compact "12 → 15" line.
  static String _trimmed(num value) =>
      formatSignedPoints(value).replaceFirst('+', '');
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final tint = enabled ? color : AppColors.onSurfaceVariant;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: tint.withValues(alpha: enabled ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: SizedBox(
            width: 48.w,
            height: 48.w,
            child: Icon(icon, size: 24.w, color: tint),
          ),
        ),
      ),
    );
  }
}
