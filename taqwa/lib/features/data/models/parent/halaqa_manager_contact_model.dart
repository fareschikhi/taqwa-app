import '../../../../core/utils/whatsapp.dart' as wa;

/// A manager of the child's halaqa, as nested in GET /students/:id/profile
/// under `halaqa.managers[].manager`. The parent reaches them on WhatsApp.
class HalaqaManagerContactModel {
  final int id;
  final String fullName;
  final String phone;

  const HalaqaManagerContactModel({
    required this.id,
    required this.fullName,
    required this.phone,
  });

  /// Every manager of the profile's halaqa that has a phone. Empty when the
  /// child has no halaqa or the halaqa has no reachable manager.
  static List<HalaqaManagerContactModel> listFromProfile(
    Map<String, dynamic> profile,
  ) {
    final halaqa = profile['halaqa'] as Map<String, dynamic>?;
    final links = (halaqa?['managers'] as List?) ?? const [];
    return links
        .cast<Map<String, dynamic>>()
        .map((link) => link['manager'] as Map<String, dynamic>?)
        .whereType<Map<String, dynamic>>()
        .map((manager) {
          final user = manager['user'] as Map<String, dynamic>?;
          return HalaqaManagerContactModel(
            id: (manager['id'] as num?)?.toInt() ?? 0,
            fullName: (user?['fullName'] as String?) ?? '',
            phone: (user?['phone'] as String?) ?? '',
          );
        })
        .where((m) => m.whatsappUri != null)
        .toList();
  }

  /// The wa.me link for [phone], or null when it cannot be dialled.
  Uri? get whatsappUri => wa.whatsappUri(phone);
}
