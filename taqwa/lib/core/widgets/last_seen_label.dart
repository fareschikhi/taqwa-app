import 'package:flutter/material.dart';
import 'package:taqwa/core/theme/app_colors.dart';
import 'package:taqwa/core/theme/app_text_styles.dart';
import 'package:taqwa/core/utils/last_seen.dart';
import 'package:taqwa/core/widgets/app_text.dart';

/// One line telling staff when a user last opened the app — "آخر دخول: أمس" —
/// or, in the error color, that they never have. Laid out like the phone row
/// on the account cards: text, then a small icon.
class LastSeenLabel extends StatelessWidget {
  const LastSeenLabel({
    super.key,
    required this.lastSeen,
    this.centered = false,
  });

  final DateTime? lastSeen;

  /// Centered for the grid card; end-aligned for the list card.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final never = lastSeen == null;
    final color = never ? AppColors.error : AppColors.onSurfaceVariant;
    final icon = never
        ? Icons.do_not_disturb_on_outlined
        : isStaleLastSeen(lastSeen)
        ? Icons.history
        : Icons.access_time;

    return Row(
      mainAxisAlignment: centered
          ? MainAxisAlignment.center
          : MainAxisAlignment.end,
      children: [
        Flexible(
          child: AppText(
            lastSeenLabel(lastSeen),
            style: AppTextStyles.labelSm.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 4),
        Icon(icon, size: 14, color: color),
      ],
    );
  }
}
