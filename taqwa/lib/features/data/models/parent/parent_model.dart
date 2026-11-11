import 'package:taqwa/core/utils/extra_phones.dart';
import 'parent_child_model.dart';

class ParentModel {
  final int? id;
  final int? userId;
  final String fullName;
  final String? phone;
  final List<String> extraPhones;
  final String? email;
  final String? avatar;
  final String? address;
  final bool? isActive;

  /// Last password sign-in, and last time the app talked to the server (a
  /// returning parent's token is refreshed, so they rarely sign in again).
  /// Null = never. Only staff-facing lists receive these.
  final DateTime? lastLoginAt;
  final DateTime? lastSeenAt;
  final List<ParentChildModel> children;

  /// The latest sign of use, or null if the parent never opened the app.
  DateTime? get lastActiveAt {
    final login = lastLoginAt, seen = lastSeenAt;
    if (login == null) return seen;
    if (seen == null) return login;
    return seen.isAfter(login) ? seen : login;
  }

  const ParentModel({
    this.id,
    this.userId,
    required this.fullName,
    this.phone,
    this.extraPhones = const [],
    this.email,
    this.avatar,
    this.address,
    this.isActive,
    this.lastLoginAt,
    this.lastSeenAt,
    this.children = const [],
  });

  factory ParentModel.fromJson(Map<String, dynamic> json) {
    // Format A: root is Parent → user fields nested under 'user'
    // Format B: root is User  → parent fields nested under 'parent'
    final userMap = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : null;
    final parentMap = json['parent'] is Map<String, dynamic>
        ? json['parent'] as Map<String, dynamic>
        : null;

    // Children come directly as Student rows (Parent.students relation)
    final rawChildren = json['students'] as List<dynamic>?;
    final childrenList = rawChildren
            ?.whereType<Map<String, dynamic>>()
            .map(ParentChildModel.fromJson)
            .toList() ??
        [];

    return ParentModel(
      // Prefer parentMap.id if root is User; fall back to root id
      id: (parentMap?['id'] as num?)?.toInt() ??
          (json['id'] as num?)?.toInt(),
      userId: (userMap?['id'] as num?)?.toInt(),

      // User fields: root first (Format B), nested 'user' second (Format A)
      fullName: (json['fullName'] as String?) ??
          (userMap?['fullName'] as String?) ??
          '',
      phone: (json['phone'] as String?) ?? (userMap?['phone'] as String?),
      extraPhones: parseExtraPhones(json['extraPhones'] ?? userMap?['extraPhones']),
      email: (json['email'] as String?) ?? (userMap?['email'] as String?),
      avatar: (json['avatar'] as String?) ?? (userMap?['avatar'] as String?),
      isActive:
          (json['isActive'] as bool?) ?? (userMap?['isActive'] as bool?),
      lastLoginAt: _date(json['lastLoginAt'] ?? userMap?['lastLoginAt']),
      lastSeenAt: _date(json['lastSeenAt'] ?? userMap?['lastSeenAt']),

      // Parent fields: root first (Format A), nested 'parent' second (Format B)
      address: (json['address'] as String?) ??
          (parentMap?['address'] as String?),

      children: childrenList,
    );
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (avatar != null) 'avatar': avatar,
        if (address != null) 'address': address,
      };
}
