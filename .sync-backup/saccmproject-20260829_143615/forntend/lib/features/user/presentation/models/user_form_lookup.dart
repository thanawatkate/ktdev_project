class UserPrefixLookupItem {
  const UserPrefixLookupItem({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;

  factory UserPrefixLookupItem.fromRow(Map<String, dynamic> row) {
    return UserPrefixLookupItem(
      id: row['id']?.toString() ?? '',
      label: (row['prefixTh'] ?? '').toString(),
    );
  }
}

class UserGroupLookupItem {
  const UserGroupLookupItem({
    required this.id,
    required this.label,
  });

  final int id;
  final String label;

  static UserGroupLookupItem? fromRow(Map<String, dynamic> row) {
    final id = _toInt(row['id']);
    if (id == null || id <= 0) return null;

    final nameTh = (row['nameth'] ?? '').toString().trim();
    final nameEn = (row['nameen'] ?? '').toString().trim();
    final label = switch ((nameTh.isNotEmpty, nameEn.isNotEmpty)) {
      (true, true) => '$nameTh ($nameEn)',
      (true, false) => nameTh,
      (false, true) => nameEn,
      (false, false) => '-',
    };

    return UserGroupLookupItem(id: id, label: label);
  }
}

int? _toInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
