import 'user_model.dart';
import 'student/student_model.dart';

class ParentModel {
  final int id;
  final int userId;
  final String? address;
  final UserModel user;
  final List<StudentModel> children;

  ParentModel({
    required this.id,
    required this.userId,
    this.address,
    required this.user,
    this.children = const [],
  });

  factory ParentModel.fromJson(Map<String, dynamic> json) {
    var childrenList = <StudentModel>[];
    if (json['children'] != null) {
      for (var item in json['children']) {
        if (item['student'] != null) {
          childrenList.add(StudentModel.fromJson(item['student']));
        }
      }
    }
    return ParentModel(
      id: json['id'],
      userId: json['userId'],
      address: json['address'],
      user: UserModel.fromJson(json['user'] ?? json),
      children: childrenList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'address': address,
      'user': user.toJson(),
      'children': children.map((s) => s.toJson()).toList(),
    };
  }
}
