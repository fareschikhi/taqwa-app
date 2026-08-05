class AuthUser {
  final int id;
  final String fullName;
  final String? email;
  final String? phone;
  final String role;
  final String? avatar;

  const AuthUser({
    required this.id,
    required this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.avatar,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'],
    fullName: json['fullName'],
    email: json['email'],
    phone: json['phone'],
    role: json['role'],
    avatar: json['avatar'],
  );
}

class AuthResponseModel {
  final String accessToken;
  final AuthUser user;

  const AuthResponseModel({required this.accessToken, required this.user});

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) =>
      AuthResponseModel(
        accessToken: json['accessToken'],
        user: AuthUser.fromJson(json['user']),
      );
}
