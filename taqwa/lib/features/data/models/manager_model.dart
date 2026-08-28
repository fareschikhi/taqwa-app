class ManagerModel {
  final int? id;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatar;
  final bool? isActive;

  /// The halaqas this manager is responsible for, already unwrapped out of the
  /// `ManagerHalaqa` join rows the API returns — each entry is the halaqa
  /// itself (`{id, name, level}`). Null when the endpoint didn't include them.
  final List<Map<String, dynamic>>? halaqas;
  final int? justificationsCount;
  final bool canManageAccounts;
  final bool canDeleteAccounts;

  const ManagerModel({
    this.id,
    required this.fullName,
    this.phone,
    this.email,
    this.avatar,
    this.isActive,
    this.halaqas,
    this.justificationsCount,
    this.canManageAccounts = false,
    this.canDeleteAccounts = false,
  });

  factory ManagerModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    List<Map<String, dynamic>>? halaqasList;
    if (json['halaqas'] != null) {
      halaqasList = (json['halaqas'] as List)
          .map((h) => h['halaqa'] as Map<String, dynamic>)
          .toList();
    }
    final count = json['_count'] as Map<String, dynamic>?;

    return ManagerModel(
      id: json['id'],
      fullName: user?['fullName'] ?? json['fullName'] ?? '',
      phone: user?['phone'] ?? json['phone'],
      email: user?['email'] ?? json['email'],
      avatar: user?['avatar'] ?? json['avatar'],
      isActive: user?['isActive'] ?? json['isActive'],
      halaqas: halaqasList,
      justificationsCount: count?['justifications'],
      canManageAccounts: (json['canManageAccounts'] as bool?) ?? false,
      canDeleteAccounts: (json['canDeleteAccounts'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'fullName': fullName,
    if (phone != null) 'phone': phone,
    if (email != null) 'email': email,
    if (avatar != null) 'avatar': avatar,
  };

  String get firstHalaqaName {
    if (halaqas == null || halaqas!.isEmpty) return 'غير معين';
    return halaqas!.first['name'] ?? 'غير معين';
  }

  int get halaqasCount => halaqas?.length ?? 0;
}
