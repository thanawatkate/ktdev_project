/// ข้อมูลโรงเรียนที่เก็บบนเครื่อง (ใช้แสดงในรายงานหรืออ้างอิงทั่วไป)
class SchoolProfile {
  final String name;
  final String address;
  final String phone;
  final String extra;

  const SchoolProfile({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.extra = '',
  });

  SchoolProfile copyWith({
    String? name,
    String? address,
    String? phone,
    String? extra,
  }) {
    return SchoolProfile(
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      extra: extra ?? this.extra,
    );
  }
}
