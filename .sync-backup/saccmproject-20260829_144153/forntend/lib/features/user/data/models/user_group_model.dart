import '../../domain/entities/user_group.dart';

class UserGroupModel extends UserGroup {
  const UserGroupModel({required super.id, required super.name});

  factory UserGroupModel.fromJson(Map<String, dynamic> json) {
    return UserGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
