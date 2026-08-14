import 'parent_child_model.dart';

class ParentModel {
  final int? id;
  final int? userId;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatar;
  final String? address;
  final bool? isActive;
  final List<ParentChildModel> children;

  const ParentModel({
    this.id,
    this.userId,
    required this.fullName,
    this.phone,
    this.email,
    this.avatar,
    this.address,
    this.isActive,
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
      email: (json['email'] as String?) ?? (userMap?['email'] as String?),
      avatar: (json['avatar'] as String?) ?? (userMap?['avatar'] as String?),
      isActive:
          (json['isActive'] as bool?) ?? (userMap?['isActive'] as bool?),

      // Parent fields: root first (Format A), nested 'parent' second (Format B)
      address: (json['address'] as String?) ??
          (parentMap?['address'] as String?),

      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        if (avatar != null) 'avatar': avatar,
        if (address != null) 'address': address,
      };
}
