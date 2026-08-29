import '../../domain/entities/prefix.dart';

class PrefixModel extends Prefix {
  const PrefixModel({required super.id, required super.prefixTh});

  factory PrefixModel.fromJson(Map<String, dynamic> json) {
    return PrefixModel(
      id: json['id']?.toString() ?? '',
      prefixTh: json['prefixth']?.toString() ?? '',
    );
  }
}
