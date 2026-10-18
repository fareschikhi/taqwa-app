import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_text.dart';

/// Telegram's own blue, so a button reads as "Telegram" at a glance.
const Color kTelegramBlue = Color(0xFF229ED9);

/// The t.me link for [phone], or null when it cannot be dialled.
///
/// The backend stores Algerian mobiles in local form ("0551234567"), while
/// t.me wants "+" and the international number ("+213551234567"). The chat
/// only opens if that person lets others find them by number in Telegram's
/// privacy settings; otherwise Telegram itself says the user was not found.
Uri? telegramUri(String? phone) {
  var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '213${digits.substring(1)}';
  if (digits.length < 8) return null;
  return Uri.parse('https://t.me/+$digits');
}

/// Opens a Telegram chat with [phone], or tells the user why it could not.
Future<void> openTelegram(BuildContext context, String? phone) async {
  final uri = telegramUri(phone);
  final opened =
      uri != null &&
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: AppText('تعذر فتح تيليجرام')));
  }
}

/// Full-width "contact via Telegram" button for a profile's contact section.
/// Renders nothing when [phone] cannot be turned into a chat link, so pages
/// can drop it in unconditionally.
class TelegramButton extends StatelessWidget {
  const TelegramButton({super.key, required this.phone});

  final String? phone;

  @override
  Widget build(BuildContext context) {
    if (telegramUri(phone) == null) return const SizedBox.shrink();
    return FilledButton.icon(
      onPressed: () => openTelegram(context, phone),
      style: FilledButton.styleFrom(
        backgroundColor: kTelegramBlue,
        foregroundColor: Colors.white,
        minimumSize: Size.fromHeight(44.h),
      ),
      icon: Icon(Icons.telegram, size: 18.w),
      label: AppText(
        'تواصل عبر تيليجرام',
        style: AppTextStyles.labelMdBold.copyWith(color: Colors.white),
      ),
    );
  }
}
