/// Mirrors the backend CreateParentDto (NestJS):
///   fullName   – required (User.fullName)
///   password   – required (User.passwordHash)
///   phone      – optional (User.phone, unique)
///   email      – optional (User.email, unique)
///   address    – optional (Parent.address)
///   avatar     – optional (User.avatar)
///   studentIds – optional, the parent's children (Student.parentId)
class ParentPayloadDto {
  final String fullName;
  final String password;
  final String? phone;
  /// More contact numbers beside [phone]; sent even when empty so an edit
  /// that removes them all clears them.
  final List<String> extraPhones;
  final String? email;
  final String? address;
  final String? avatar;
  final List<int> studentIds;

  const ParentPayloadDto({
    required this.fullName,
    required this.password,
    this.phone,
    this.extraPhones = const [],
    this.email,
    this.address,
    this.avatar,
    this.studentIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'password': password,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        'extraPhones': extraPhones,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
        if (studentIds.isNotEmpty) 'studentIds': studentIds,
      };
}
