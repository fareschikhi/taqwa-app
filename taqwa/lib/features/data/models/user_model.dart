enum UserRole { admin, teacher, parent, student, adultStudent, manager }

class UserModel {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final UserRole role;
  final String? avatar;
  final bool isActive;
  final int? studentId;
  final int? parentId;
  final int? teacherId;
  final int? managerId;
  final bool canManageAccounts;
  final bool canDeleteAccounts;

  UserModel({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.avatar,
    this.isActive = true,
    this.studentId,
    this.parentId,
    this.teacherId,
    this.managerId,
    this.canManageAccounts = false,
    this.canDeleteAccounts = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    UserRole roleVal = UserRole.student;
    switch (json['role']) {
      case 'ADMIN':
        roleVal = UserRole.admin;
        break;
      case 'TEACHER':
        roleVal = UserRole.teacher;
        break;
      case 'PARENT':
        roleVal = UserRole.parent;
        break;
      case 'STUDENT':
        roleVal = UserRole.student;
        break;
      case 'ADULT_STUDENT':
        roleVal = UserRole.adultStudent;
        break;
      case 'MANAGER':
        roleVal = UserRole.manager;
        break;
    }

    int? sId;
    if (json['student'] != null) {
      sId = json['student']['id'];
    }
    int? pId;
    if (json['parent'] != null) {
      pId = json['parent']['id'];
    }
    int? tId;
    if (json['teacher'] != null) {
      tId = json['teacher']['id'];
    }

    int? mId;
    bool canManage = false;
    bool canDelete = false;
    if (json['manager'] != null) {
      final m = json['manager'] as Map<String, dynamic>;
      mId = (m['id'] as num?)?.toInt();
      canManage = (m['canManageAccounts'] as bool?) ?? false;
      canDelete = (m['canDeleteAccounts'] as bool?) ?? false;
    }

    return UserModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      fullName: (json['fullName'] as String?) ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: roleVal,
      avatar: (json['avatar'] as String?) ?? (json['image'] as String?),
      isActive: (json['isActive'] as bool?) ?? true,
      studentId: sId,
      parentId: pId,
      teacherId: tId,
      managerId: mId,
      canManageAccounts: canManage,
      canDeleteAccounts: canDelete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      // Written out explicitly rather than derived from the Dart identifier:
      // `role.name.toUpperCase()` would turn `adultStudent` into
      // `ADULTSTUDENT`, which the API does not recognise.
      'role': switch (role) {
        UserRole.admin => 'ADMIN',
        UserRole.teacher => 'TEACHER',
        UserRole.parent => 'PARENT',
        UserRole.student => 'STUDENT',
        UserRole.adultStudent => 'ADULT_STUDENT',
        UserRole.manager => 'MANAGER',
      },
      'avatar': avatar,
      'isActive': isActive,
      if (studentId != null) 'student': {'id': studentId},
      if (parentId != null) 'parent': {'id': parentId},
      if (teacherId != null) 'teacher': {'id': teacherId},
      if (managerId != null)
        'manager': {
          'id': managerId,
          'canManageAccounts': canManageAccounts,
          'canDeleteAccounts': canDeleteAccounts,
        },
    };
  }
}
