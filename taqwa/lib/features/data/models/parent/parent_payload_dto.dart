/// Mirrors the backend CreateParentDto (NestJS):
///   fullName   – required (User.fullName)
///   password   – required (User.passwordHash)
///   phone      – optional (User.phone, unique)
///   email      – optional (User.email, unique)
///   address    – optional (Parent.address)
///   avatar     – optional (User.avatar)
/// Children are linked from the student side (Student.parentId), not here.
class ParentPayloadDto {
  final String fullName;
  final String password;
  final String? phone;
  final String? email;
  final String? address;
  final String? avatar;

  const ParentPayloadDto({
    required this.fullName,
    required this.password,
    this.phone,
    this.email,
    this.address,
    this.avatar,
  });

  Map<String, dynamic> toJson() => {
        'fullName': fullName,
        'password': password,
        if (phone != null && phone!.isNotEmpty) 'phone': phone,
        if (email != null && email!.isNotEmpty) 'email': email,
        if (address != null && address!.isNotEmpty) 'address': address,
        if (avatar != null && avatar!.isNotEmpty) 'avatar': avatar,
      };
}
