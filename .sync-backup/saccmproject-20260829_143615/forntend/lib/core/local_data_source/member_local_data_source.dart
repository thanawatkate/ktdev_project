import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/local_data_source/base_local_data_source.dart';

class MemberModel {
  final String id;
  final String code;
  final String name;
  final String email;
  final String phone;
  final String address;
  final bool synced;

  MemberModel({
    required this.id,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.synced = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'synced': synced ? 1 : 0,
      };

  factory MemberModel.fromJson(Map<String, dynamic> json) => MemberModel(
        id: json['id'] as String? ?? '',
        code: json['code'] as String? ?? '',
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        address: json['address'] as String? ?? '',
        synced: (json['synced'] as int? ?? 1) == 1,
      );
}

class MemberLocalDataSource extends BaseLocalDataSource {
  /// บันทึก member ลง local database
  Future<void> saveMember(MemberModel member, {bool synced = true}) async {
    await db.insert(
      'member',
      {
        'id': member.id,
        'code': member.code,
        'name': member.name,
        'email': member.email,
        'phone': member.phone,
        'address': member.address,
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// บันทึก multiple members
  Future<void> saveMembers(List<MemberModel> members) async {
    final deleting = await pendingDeleteProtectionFor('member_delete_');
    final unsyncedRows = await db.query(
      'member',
      columns: ['id'],
      where: 'synced = 0',
    );
    final protectedIds = unsyncedRows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final batch = db.batch();
    for (final member in members) {
      if (protectedIds.contains(member.id) ||
          deleting.protects(id: member.id, docno: member.code)) {
        continue;
      }
      batch.insert(
        'member',
        {
          'id': member.id,
          'code': member.code,
          'name': member.name,
          'email': member.email,
          'phone': member.phone,
          'address': member.address,
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// ดึง member ทั้งหมด
  Future<List<MemberModel>> getAllMembers() async {
    final results = await db.query('member', orderBy: 'name ASC');
    return results
        .map((e) => MemberModel(
              id: e['id'] as String? ?? '',
              code: e['code'] as String? ?? '',
              name: e['name'] as String? ?? '',
              email: e['email'] as String? ?? '',
              phone: e['phone'] as String? ?? '',
              address: e['address'] as String? ?? '',
              synced: (e['synced'] as int? ?? 1) == 1,
            ))
        .toList();
  }

  /// ดึง member ตาม id
  Future<MemberModel?> getMemberById(String id) async {
    final results = await db.query(
      'member',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isEmpty) return null;

    final e = results.first;
    return MemberModel(
      id: e['id'] as String? ?? '',
      code: e['code'] as String? ?? '',
      name: e['name'] as String? ?? '',
      email: e['email'] as String? ?? '',
      phone: e['phone'] as String? ?? '',
      address: e['address'] as String? ?? '',
      synced: (e['synced'] as int? ?? 1) == 1,
    );
  }

  /// ลบ member
  Future<void> deleteMember(String id) async {
    await db.delete('member', where: 'id = ?', whereArgs: [id]);
  }

  /// ล้าง member ทั้งหมด
  Future<void> clearAllMembers() async {
    await db.delete('member');
  }

  /// Mark member as synced
  Future<void> markAsSynced(String id) async {
    await db.update(
      'member',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
