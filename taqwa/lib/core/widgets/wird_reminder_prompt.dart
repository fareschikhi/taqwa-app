import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/core/widgets/wird_reminder_card.dart';
import 'package:taqwa/features/data/services/wird_reminder_service.dart';

/// Turns the daily wird reminder on for [userId] the first time their home
/// opens on this phone, and asks them which hour suits them.
///
/// It wraps the home every role lands on, so it only ever runs after the
/// forced password change: an account still on its admin-set password is held
/// on that screen and never reaches here.
///
/// The reminder is on by default — closing the popup without choosing keeps
/// the hour already shown (8:00 م unless they set one before) — and the
/// dashboard card stays the place to move it or switch it off.
class WirdReminderPrompt extends StatefulWidget {
  const WirdReminderPrompt({
    super.key,
    required this.userId,
    required this.child,
    this.service,
    this.enabled,
  });

  final int userId;
  final Widget child;

  /// Overridable for tests; the app uses [WirdReminderService.instance].
  final WirdReminderService? service;

  /// Defaults to [WirdReminderService.isSupported]; tests turn it on.
  final bool? enabled;

  @override
  State<WirdReminderPrompt> createState() => _WirdReminderPromptState();
}

class _WirdReminderPromptState extends State<WirdReminderPrompt> {
  WirdReminderService get _service =>
      widget.service ?? WirdReminderService.instance;

  @override
  void initState() {
    super.initState();
    if (!(widget.enabled ?? WirdReminderService.isSupported)) return;
    // After the first frame, so the home is drawn behind the popup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    final WirdReminderSettings current;
    try {
      if (!await _service.shouldPrompt(widget.userId)) return;
      current = await _service.load();
    } catch (_) {
      return; // Unreadable storage: the card still works by hand.
    }
    if (!mounted) return;

    final chosen = await WirdTimeDialog.show(context, initial: current.time);
    // Marked before scheduling, so a refused permission does not bring the
    // popup back on every launch; the card explains the refusal instead.
    await _service.markPrompted(widget.userId);
    final time = chosen ?? current.time;
    final result = await _service.enable(time);
    if (!mounted) return;

    final message = switch (result) {
      WirdReminderResult.scheduled =>
        'سنذكّرك بوردك كل يوم الساعة ${formatWirdTime(time)}',
      WirdReminderResult.permissionDenied =>
        'الإشعارات مغلقة، فعّلها من إعدادات الهاتف ليصلك تذكير الورد',
      WirdReminderResult.failed => 'تعذّر ضبط تذكير الورد، جرّبه من بطاقة وردك',
    };
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// The popup itself: the hour as one large button that opens the picker, and
/// a single "save" action.
class WirdTimeDialog extends StatefulWidget {
  const WirdTimeDialog({super.key, required this.initial});

  final TimeOfDay initial;

  /// The hour the user saved, or `null` if they closed the popup.
  static Future<TimeOfDay?> show(
    BuildContext context, {
    required TimeOfDay initial,
  }) => showDialog<TimeOfDay>(
    context: context,
    builder: (_) => WirdTimeDialog(initial: initial),
  );

  @override
  State<WirdTimeDialog> createState() => _WirdTimeDialogState();
}

class _WirdTimeDialogState extends State<WirdTimeDialog> {
  late TimeOfDay _time = widget.initial;

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'وقت تذكير الورد',
      cancelText: 'إلغاء',
      confirmText: 'تم',
      // Same RTL frame the card gives the picker.
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusXl),
      ),
      // Scrolls rather than overflowing on a short phone with large text.
      child: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.35),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: AppColors.primary,
                    size: 22.w,
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: AppText(
                    'وردك اليومي',
                    style: AppTextStyles.headlineSm.copyWith(
                      color: AppColors.onSurface,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            AppText(
              'فعّلنا لك تذكيراً يومياً بوردك من القرآن الكريم. اختر الوقت الذي يناسبك.',
              style: AppTextStyles.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.end,
            ),
            SizedBox(height: 16.h),
            _buildTimeButton(),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _time),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                  ),
                ),
                child: AppText(
                  'حفظ الوقت',
                  style: AppTextStyles.button.copyWith(
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Matches the card's time strip, so the popup and the card read as one.
  Widget _buildTimeButton() {
    return Material(
      color: AppColors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      child: InkWell(
        onTap: _pickTime,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Semantics(
          button: true,
          label: 'اختيار وقت التذكير، الحالي ${formatWirdTime(_time)}',
          excludeSemantics: true,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
            child: Row(
              children: [
                Icon(Icons.edit_outlined, size: 18.w, color: AppColors.primary),
                SizedBox(width: 4.w),
                AppText(
                  'تغيير',
                  style: AppTextStyles.labelMdBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 8.w),
                // Takes what is left, so a narrow dialog wraps instead of
                // overflowing.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(
                        'وقت التذكير',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.end,
                      ),
                      AppText(
                        formatWirdTime(_time),
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                Icon(
                  Icons.schedule_rounded,
                  size: 22.w,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
