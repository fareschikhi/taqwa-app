import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/app_text.dart';

/// WhatsApp's own green, so a button reads as "WhatsApp" at a glance.
const Color kWhatsappGreen = Color(0xFF25D366);

/// The wa.me link for [phone], or null when it cannot be dialled.
///
/// The backend stores Algerian mobiles in local form ("0551234567"), while
/// WhatsApp wants the international number without "+" ("213551234567").
Uri? whatsappUri(String? phone) {
  var digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
  if (digits.startsWith('00')) digits = digits.substring(2);
  if (digits.startsWith('0')) digits = '213${digits.substring(1)}';
  if (digits.length < 8) return null;
  return Uri.parse('https://wa.me/$digits');
}

/// Opens a WhatsApp chat with [phone], or tells the user why it could not.
Future<void> openWhatsapp(BuildContext context, String? phone) async {
  final uri = whatsappUri(phone);
  final opened =
      uri != null &&
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      ).catchError((_) => false);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: AppText('تعذر فتح واتساب')));
  }
}
