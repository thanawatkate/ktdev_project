import '../../domain/entities/source_group.dart';

class SourceGroupModel extends SourceGroup {
  const SourceGroupModel({required super.id, required super.name});

  factory SourceGroupModel.fromJson(Map<String, dynamic> json) {
    return SourceGroupModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}
