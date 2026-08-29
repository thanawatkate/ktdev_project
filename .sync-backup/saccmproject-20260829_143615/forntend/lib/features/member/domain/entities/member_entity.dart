class MemberEntity {
  final String? id;
  final String code;
  final String name;
  final String lastName;
  final String email;
  final String contactNumber;
  final String address;
  final String refPrefix;

  const MemberEntity({
    this.id,
    required this.code,
    required this.name,
    required this.lastName,
    required this.email,
    required this.contactNumber,
    required this.address,
    required this.refPrefix,
  });
}
