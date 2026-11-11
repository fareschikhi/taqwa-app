import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:taqwa/core/constants/app_constants.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/widgets/app_card.dart';
import 'package:taqwa/core/widgets/app_text.dart';
import 'package:taqwa/features/data/services/wird_reminder_service.dart';

/// `9:30 م` — the same 12-hour reading people say the time in.
String formatWirdTime(TimeOfDay time) {
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${time.period == DayPeriod.am ? 'ص' : 'م'}';
}

/// وردك اليومي on the dashboards: switch the daily reminder on or off and
/// pick the hour it arrives.
///
/// Every role but parents gets it (see offersWirdReminder), and it owns
/// its own state, because the setting belongs to the phone rather than to
/// anything the dashboard loads. Dashboards check [isAvailable] first so the
/// web build, which cannot schedule notifications, shows no dead switch.
class WirdReminderCard extends StatefulWidget {
  const WirdReminderCard({super.key, this.service});

  /// Overridable for tests; the app uses [WirdReminderService.instance].
  final WirdReminderService? service;

  static bool get isAvailable => WirdReminderService.isSupported;

  @override
  State<WirdReminderCard> createState() => _WirdReminderCardState();
}

class _WirdReminderCardState extends State<WirdReminderCard> {
  WirdReminderService get _service =>
      widget.service ?? WirdReminderService.instance;

  bool _enabled = false;
  TimeOfDay _time = WirdReminderService.defaultTime;
  bool _loaded = false;
  bool _busy = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    // The sign-in popup can turn the reminder on while this card is already
    // drawn underneath it; reload whenever the service saves.
    _service.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _service.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    WirdReminderSettings? settings;
    try {
      settings = await _service.load();
    } catch (_) {
      // Unreadable storage shows the defaults: off, at the default hour.
    }
    if (!mounted) return;
    setState(() {
      _enabled = settings?.enabled ?? false;
      _time = settings?.time ?? WirdReminderService.defaultTime;
      _loaded = true;
    });
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      await _schedule(_time);
    } else {
      setState(() {
        _busy = true;
        _enabled = false;
        _permissionDenied = false;
      });
      try {
        await _service.disable(_time);
      } catch (_) {
        // Saved as off either way; a cancel that failed leaves at most one
        // stray reminder, which the next switch-on replaces.
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: 'وقت تذكير الورد',
      cancelText: 'إلغاء',
      confirmText: 'حفظ',
      // The app runs LTR and right-aligns its Arabic by hand; the picker has
      // no such care, so it is given a proper RTL frame of its own.
      builder: (context, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
    );
    if (picked == null || picked == _time) return;
    await _schedule(picked, announce: true);
  }

  Future<void> _schedule(TimeOfDay time, {bool announce = false}) async {
    setState(() {
      _busy = true;
      _permissionDenied = false;
    });
    final result = await _service.enable(time);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == WirdReminderResult.scheduled) {
        _enabled = true;
        _time = time;
      }
      _permissionDenied = result == WirdReminderResult.permissionDenied;
    });

    final message = switch (result) {
      WirdReminderResult.scheduled when announce =>
        'سنذكّرك بوردك كل يوم الساعة ${formatWirdTime(time)}',
      WirdReminderResult.failed => 'تعذّر ضبط التذكير، حاول مرة أخرى',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        AppText(
          'وردك اليومي',
          style: AppTextStyles.headlineSm.copyWith(color: AppColors.onSurface),
        ),
        SizedBox(height: 12.h),
        AppCard(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildToggleRow(),
              AnimatedSize(
                duration: AppConstants.animNormal,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _enabled ? _buildTimeRow() : const SizedBox.shrink(),
              ),
              if (_permissionDenied) _buildPermissionNotice(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow() {
    final canToggle = _loaded && !_busy;
    return MergeSemantics(
      child: InkWell(
        onTap: canToggle ? () => _toggle(!_enabled) : null,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: Row(
          children: [
            Switch(
              value: _enabled,
              onChanged: canToggle ? _toggle : null,
              activeThumbColor: AppColors.primary,
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppText(
                    'تذكير الورد',
                    style: AppTextStyles.bodyMdBold.copyWith(
                      color: AppColors.onSurface,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  AppText(
                    _enabled
                        ? 'يصلك إشعار «لا تنسَ وردك» كل يوم'
                        : 'فعّله ليصلك إشعار يومي بوردك من القرآن',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedContainer(
              duration: AppConstants.animNormal,
              width: AppConstants.iconContainerSize,
              height: AppConstants.iconContainerSize,
              decoration: BoxDecoration(
                color: _enabled
                    ? AppColors.primaryContainer.withValues(alpha: 0.35)
                    : AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppConstants.radiusMd),
              ),
              child: _busy
                  ? Padding(
                      padding: EdgeInsets.all(11.w),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(
                      _enabled
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_off_outlined,
                      size: 22.w,
                      color: _enabled ? AppColors.primary : AppColors.outline,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// The hour, large enough to read at a glance, and the whole strip is the
  /// button that changes it.
  Widget _buildTimeRow() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Material(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        child: InkWell(
          onTap: _busy ? null : _pickTime,
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
          child: Semantics(
            button: true,
            label: 'تغيير وقت التذكير، الحالي ${formatWirdTime(_time)}',
            excludeSemantics: true,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 18.w,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4.w),
                  AppText(
                    'تغيير',
                    style: AppTextStyles.labelMdBold.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(
                        'وقت التذكير',
                        style: AppTextStyles.labelSm.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                      AppText(
                        formatWirdTime(_time),
                        style: AppTextStyles.headlineSm.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Widget _buildPermissionNotice() {
    return Padding(
      padding: EdgeInsets.only(top: 12.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: AppColors.errorContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppText(
                'الإشعارات مغلقة لهذا التطبيق. فعّلها من إعدادات الهاتف ثم أعد تشغيل التذكير.',
                style: AppTextStyles.labelSm.copyWith(
                  color: AppColors.onErrorContainer,
                ),
                textAlign: TextAlign.end,
              ),
            ),
            SizedBox(width: 8.w),
            Icon(
              Icons.info_outline_rounded,
              size: 18.w,
              color: AppColors.onErrorContainer,
            ),
          ],
        ),
      ),
    );
  }
}
