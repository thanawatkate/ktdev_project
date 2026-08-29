import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'app_database.dart';

/// Local user record returned after successful offline login.
class LocalUser {
  final int id;
  final String code;
  final String username;
  final String email;
  final String name;
  final String lastname;
  final String contactNumber;
  final String? refPrefix;
  final int? refUserGroup;
  final String? userGroupNameTh;
  final String? userGroupNameEn;
  final bool forcePasswordChange;
  final bool isActive;
  final Set<String> permissions;

  const LocalUser({
    required this.id,
    required this.code,
    required this.username,
    required this.email,
    required this.name,
    required this.lastname,
    this.contactNumber = '',
    this.refPrefix,
    this.refUserGroup,
    this.userGroupNameTh,
    this.userGroupNameEn,
    this.forcePasswordChange = false,
    this.isActive = true,
    this.permissions = const <String>{},
  });

  bool get isAdmin => userGroupNameEn?.toLowerCase() == 'admin';

  String get fullName => '$name $lastname';
}

class UserLocalDataSource {
  final AppDatabase _db;

  UserLocalDataSource({AppDatabase? db}) : _db = db ?? AppDatabase();

  /// SHA-256(username + password) — matches the hashing used in [AppDatabase._hashPassword].
  static String hashPassword(String username, String password) {
    final bytes = utf8.encode('$username$password');
    return sha256.convert(bytes).toString();
  }

  /// Returns [LocalUser] if credentials match, or null if not found / wrong password.
  Future<LocalUser?> login({
    required String username,
    required String password,
  }) async {
    final db = await _db.database;
    final hash = hashPassword(username, password);

    final rows = await db.rawQuery('''
      SELECT u.id, u.code, u.username, u.email, u.name, u.lastname,
             u.contactnumber, u.refprefix, u.refusergroup,
             u.forcePasswordChange, u.isActive,
             g.nameth AS groupNameTh, g.nameen AS groupNameEn
      FROM users u
      LEFT JOIN usergroup g ON g.id = u.refusergroup
      WHERE u.username = ? AND u.password = ? AND COALESCE(u.isActive, 1) = 1
      LIMIT 1
    ''', [username, hash]);

    if (rows.isEmpty) return null;

    final row = rows.first;
    final refUserGroup = row['refusergroup'] as int?;
    final permissions = await getPermissionsByUserGroup(refUserGroup);
    return LocalUser(
      id: row['id'] as int,
      code: (row['code'] as String?) ?? '',
      username: row['username'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      lastname: row['lastname'] as String,
      contactNumber: (row['contactnumber'] as String?) ?? '',
      refPrefix: row['refprefix']?.toString(),
      refUserGroup: refUserGroup,
      forcePasswordChange: ((row['forcePasswordChange'] as int?) ?? 0) == 1,
      isActive: ((row['isActive'] as int?) ?? 1) == 1,
      userGroupNameTh: row['groupNameTh'] as String?,
      userGroupNameEn: row['groupNameEn'] as String?,
      permissions: permissions,
    );
  }

  /// Returns [LocalUser] by username (without password check), or null if missing.
  Future<LocalUser?> getUserByUsername(String username) async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT u.id, u.code, u.username, u.email, u.name, u.lastname,
             u.contactnumber, u.refprefix, u.refusergroup,
             u.forcePasswordChange, u.isActive,
             g.nameth AS groupNameTh, g.nameen AS groupNameEn
      FROM users u
      LEFT JOIN usergroup g ON g.id = u.refusergroup
      WHERE u.username = ?
      LIMIT 1
    ''', [username]);

    if (rows.isEmpty) return null;
    final row = rows.first;
    return LocalUser(
      id: row['id'] as int,
      code: (row['code'] as String?) ?? '',
      username: row['username'] as String,
      email: row['email'] as String,
      name: row['name'] as String,
      lastname: row['lastname'] as String,
      contactNumber: (row['contactnumber'] as String?) ?? '',
      refPrefix: row['refprefix']?.toString(),
      refUserGroup: row['refusergroup'] as int?,
      forcePasswordChange: ((row['forcePasswordChange'] as int?) ?? 0) == 1,
      isActive: ((row['isActive'] as int?) ?? 1) == 1,
      userGroupNameTh: row['groupNameTh'] as String?,
      userGroupNameEn: row['groupNameEn'] as String?,
    );
  }

  /// สร้างผู้ดูแลระบบหลังเปิดใช้งานออนไลน์ (ถ้ายังไม่มีใน SQLite)
  Future<void> ensureActivationAdminUser({
    required String username,
    required String password,
    required String name,
    required String lastname,
    String email = '',
  }) async {
    final existing = await getUserByUsername(username);
    if (existing != null) return;

    final db = await _db.database;
    final groups = await db.query(
      'usergroup',
      columns: ['id'],
      where: 'nameen = ?',
      whereArgs: ['admin'],
      limit: 1,
    );
    final adminGroupId = groups.isNotEmpty ? groups.first['id'] as int : 1;

    await db.insert('users', {
      'code': '01',
      'email': email.isNotEmpty ? email : '$username@school.local',
      'username': username,
      'password': hashPassword(username, password),
      'name': name,
      'lastname': lastname,
      'contactnumber': '',
      'refusergroup': adminGroupId,
      'forcePasswordChange': 0,
      'isActive': 1,
    });
  }

  /// Get all users (for admin management screen).
  Future<List<LocalUser>> getAllUsers() async {
    final db = await _db.database;
    final rows = await db.rawQuery('''
      SELECT u.id, u.code, u.username, u.email, u.name, u.lastname,
             u.contactnumber, u.refprefix, u.refusergroup,
             u.forcePasswordChange, u.isActive,
             g.nameth AS groupNameTh, g.nameen AS groupNameEn
      FROM users u
      LEFT JOIN usergroup g ON g.id = u.refusergroup
      ORDER BY u.id ASC
    ''');

    return rows
        .map((row) => LocalUser(
              id: row['id'] as int,
              code: (row['code'] as String?) ?? '',
              username: row['username'] as String,
              email: row['email'] as String,
              name: row['name'] as String,
              lastname: row['lastname'] as String,
              contactNumber: (row['contactnumber'] as String?) ?? '',
              refPrefix: row['refprefix']?.toString(),
              refUserGroup: row['refusergroup'] as int?,
              forcePasswordChange:
                  ((row['forcePasswordChange'] as int?) ?? 0) == 1,
              isActive: ((row['isActive'] as int?) ?? 1) == 1,
              userGroupNameTh: row['groupNameTh'] as String?,
              userGroupNameEn: row['groupNameEn'] as String?,
            ))
        .toList();
  }

  /// Update password for a user (offline).
  Future<void> changePassword({
    required int userId,
    required String username,
    required String newPassword,
  }) async {
    final db = await _db.database;
    await db.update(
      'users',
      {
        'password': hashPassword(username, newPassword),
        'forcePasswordChange': 0,
        'updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
  }

  Future<bool> changePasswordByCredentials({
    required String username,
    required String currentPassword,
    required String newPassword,
  }) async {
    final db = await _db.database;
    final currentHash = hashPassword(username, currentPassword);
    final newHash = hashPassword(username, newPassword);

    final updated = await db.update(
      'users',
      {
        'password': newHash,
        'forcePasswordChange': 0,
        'updated': DateTime.now().toIso8601String(),
      },
      where: 'username = ? AND password = ?',
      whereArgs: [username, currentHash],
    );
    return updated > 0;
  }

  Future<List<Map<String, dynamic>>> getUserGroups() async {
    final db = await _db.database;
    return db.query(
      'usergroup',
      columns: ['id', 'nameth', 'nameen'],
      orderBy: 'id ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getPrefixes() async {
    final db = await _db.database;
    return db.query(
      'prefix',
      columns: ['id', 'prefixTh'],
      orderBy: 'id ASC',
    );
  }

  Future<Set<String>> getPermissionsByUserGroup(int? userGroupId) async {
    if (userGroupId == null) return const <String>{};
    final db = await _db.database;
    final rows = await db.query(
      'usergroup_permission',
      columns: ['permission_key'],
      where: 'usergroup_id = ?',
      whereArgs: [userGroupId],
    );
    return rows
        .map((e) => (e['permission_key'] as String?)?.trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toSet();
  }

  Future<bool> replacePermissionsByUserGroup({
    required int userGroupId,
    required Set<String> permissions,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(
        'usergroup_permission',
        where: 'usergroup_id = ?',
        whereArgs: [userGroupId],
      );
      for (final key in permissions) {
        await txn.insert(
          'usergroup_permission',
          {'usergroup_id': userGroupId, 'permission_key': key},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });
    return true;
  }

  Future<bool> createUser({
    required String code,
    required String email,
    required String username,
    required String password,
    required String name,
    required String lastname,
    required int refUserGroup,
    String? refPrefix,
    String contactNumber = '',
    int forcePasswordChange = 1,
  }) async {
    final db = await _db.database;
    final exists = await db.query(
      'users',
      columns: ['id'],
      where: 'username = ?',
      whereArgs: [username],
      limit: 1,
    );
    if (exists.isNotEmpty) return false;

    await db.insert('users', {
      'code': code,
      'email': email,
      'username': username,
      'password': hashPassword(username, password),
      'name': name,
      'lastname': lastname,
      'contactnumber': contactNumber,
      'refusergroup': refUserGroup,
      'refprefix': refPrefix,
      'forcePasswordChange': forcePasswordChange,
      'isActive': 1,
      'created': DateTime.now().toIso8601String(),
      'updated': DateTime.now().toIso8601String(),
      'synced': 0,
      'lastModified': DateTime.now().toIso8601String(),
    });
    return true;
  }

  Future<bool> updateUser({
    required int userId,
    required String code,
    required String email,
    required String username,
    required String name,
    required String lastname,
    required int refUserGroup,
    String? refPrefix,
    String contactNumber = '',
    String? newPassword,
  }) async {
    final db = await _db.database;
    final values = <String, Object?>{
      'code': code,
      'email': email,
      'name': name,
      'lastname': lastname,
      'contactnumber': contactNumber,
      'refusergroup': refUserGroup,
      'refprefix': refPrefix,
      'updated': DateTime.now().toIso8601String(),
      'synced': 0,
      'lastModified': DateTime.now().toIso8601String(),
    };
    final password = newPassword?.trim() ?? '';
    if (password.isNotEmpty) {
      values['password'] = hashPassword(username, password);
      values['forcePasswordChange'] = 1;
    }

    final updated = await db.update(
      'users',
      values,
      where: 'id = ?',
      whereArgs: [userId],
    );
    return updated > 0;
  }

  Future<bool> resetPassword({
    required int userId,
    required String username,
    required String newPassword,
    int forcePasswordChange = 1,
  }) async {
    final db = await _db.database;
    final updated = await db.update(
      'users',
      {
        'password': hashPassword(username, newPassword),
        'forcePasswordChange': forcePasswordChange,
        'updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    return updated > 0;
  }

  Future<bool> updateUserGroup({
    required int userId,
    required int refUserGroup,
  }) async {
    final db = await _db.database;
    final updated = await db.update(
      'users',
      {
        'refusergroup': refUserGroup,
        'updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    return updated > 0;
  }

  Future<bool> setUserActive({
    required int userId,
    required bool isActive,
  }) async {
    final db = await _db.database;
    final updated = await db.update(
      'users',
      {
        'isActive': isActive ? 1 : 0,
        'updated': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [userId],
    );
    return updated > 0;
  }
}
