import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart' show ConflictAlgorithm, Database;

import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/features/auth/presentation/providers/simple_auth_provider.dart';
import 'package:saccm/features/home/presentation/pages/home_nav_index.dart';

import 'app_database.dart';
import 'app_menu_seed_data.dart';

/// แถวจากตาราง [app_menu] (SQLite)
class AppMenuRow {
  final int id;
  final int? parentId;
  final String slug;
  final String nameTh;
  final String nameEn;
  final String? routeKey;
  final String? requiredPermission;
  final String? iconKey;
  final int sortOrder;
  final int? navIndex;
  final int isActive;

  const AppMenuRow({
    required this.id,
    this.parentId,
    required this.slug,
    required this.nameTh,
    required this.nameEn,
    this.routeKey,
    this.requiredPermission,
    this.iconKey,
    required this.sortOrder,
    this.navIndex,
    required this.isActive,
  });

  factory AppMenuRow.fromMap(Map<String, Object?> m) {
    int asInt(Object? v) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v?.toString() ?? '') ?? 0;
    }

    int? parent(Object? v) {
      if (v == null) return null;
      return asInt(v);
    }

    return AppMenuRow(
      id: asInt(m['id']),
      parentId: parent(m['parent_id']),
      slug: (m['slug'] as String?) ?? '',
      nameTh: (m['name_th'] as String?) ?? '',
      nameEn: (m['name_en'] as String?) ?? '',
      routeKey: m['route_key'] as String?,
      requiredPermission: m['required_permission'] as String?,
      iconKey: m['icon_key'] as String?,
      sortOrder: asInt(m['sort_order']),
      navIndex: m['nav_index'] == null ? null : asInt(m['nav_index']),
      isActive: asInt(m['is_active'] ?? 1) == 0 ? 0 : 1,
    );
  }
}

class NavMenuSectionSpec {
  final String title;
  final List<int> navIndexes;

  const NavMenuSectionSpec({required this.title, required this.navIndexes});
}

class NavMenuSlot {
  final int navIndex;
  final String label;
  final IconData icon;
  final String requiredPermission;

  const NavMenuSlot({
    required this.navIndex,
    required this.label,
    required this.icon,
    required this.requiredPermission,
  });
}

class NavMenuSnapshot {
  final List<NavMenuSectionSpec> sections;
  final Map<int, NavMenuSlot> slotsByNavIndex;

  const NavMenuSnapshot({
    required this.sections,
    required this.slotsByNavIndex,
  });

  static final Map<String, IconData> _icons = {
    'home_rounded': Icons.home_rounded,
    'south_rounded': Icons.south_rounded,
    'north_rounded': Icons.north_rounded,
    'account_balance_rounded': Icons.account_balance_rounded,
    'task_alt_rounded': Icons.task_alt_rounded,
    'bar_chart_rounded': Icons.bar_chart_rounded,
    'settings_rounded': Icons.settings_rounded,
    'menu_book_outlined': Icons.menu_book_outlined,
    'logout_rounded': Icons.logout_rounded,
    'fact_check_outlined': Icons.fact_check_outlined,
    'description_outlined': Icons.description_outlined,
    'request_quote_outlined': Icons.request_quote_outlined,
  };

  static IconData iconForKey(String? key) =>
      _icons[key ?? ''] ?? Icons.circle_outlined;

  static NavMenuSnapshot fallback() {
    final rows = AppMenuSeedData.sqliteRows().map(AppMenuRow.fromMap).toList();
    return fromFlatRows(rows);
  }

  /// หน้าหลัก / ตั้งค่า / ออกจากระบบ ฝังในแอป — ไม่มาจากแถว [app_menu]
  static bool _isFixedNavExcludedFromDbTree(AppMenuRow r) {
    if (r.slug == 'section_overview') return true;
    const slugs = {'home', 'setting', 'logout'};
    if (slugs.contains(r.slug)) return true;
    final ni = r.navIndex;
    return ni == HomeNavIndex.home ||
        ni == HomeNavIndex.setting ||
        ni == HomeNavIndex.logout;
  }

  static Map<int, NavMenuSlot> _fixedNavSlots() {
    return {
      HomeNavIndex.home: const NavMenuSlot(
        navIndex: HomeNavIndex.home,
        label: TransactionUiText.home,
        icon: Icons.home_rounded,
        requiredPermission: PermissionKey.navHome,
      ),
      HomeNavIndex.setting: const NavMenuSlot(
        navIndex: HomeNavIndex.setting,
        label: TransactionUiText.systemSetting,
        icon: Icons.settings_rounded,
        requiredPermission: PermissionKey.settingView,
      ),
      HomeNavIndex.logout: const NavMenuSlot(
        navIndex: HomeNavIndex.logout,
        label: TransactionUiText.exitProgram,
        icon: Icons.logout_rounded,
        requiredPermission: PermissionKey.navLogout,
      ),
    };
  }

  static NavMenuSnapshot _mergeFixedNavSlots(NavMenuSnapshot base) {
    const systemTitleFallback = 'ระบบ';
    final slots = Map<int, NavMenuSlot>.from(base.slotsByNavIndex);
    for (final e in _fixedNavSlots().entries) {
      slots[e.key] = e.value;
    }

    const overview = NavMenuSectionSpec(
      title: TransactionUiText.overviewTab,
      navIndexes: [HomeNavIndex.home],
    );

    var usageSectionIdx = -1;
    for (var i = 0; i < base.sections.length; i++) {
      if (base.sections[i].navIndexes.contains(HomeNavIndex.usageGuide)) {
        usageSectionIdx = i;
        break;
      }
    }

    final outSections = <NavMenuSectionSpec>[overview];
    for (var i = 0; i < base.sections.length; i++) {
      final s = base.sections[i];
      if (i == usageSectionIdx) {
        final middle = s.navIndexes
            .where(
              (n) =>
                  n != HomeNavIndex.home &&
                  n != HomeNavIndex.setting &&
                  n != HomeNavIndex.logout,
            )
            .toList();
        outSections.add(
          NavMenuSectionSpec(
            title: s.title,
            navIndexes: [
              HomeNavIndex.setting,
              ...middle,
              HomeNavIndex.logout,
            ],
          ),
        );
      } else {
        outSections.add(s);
      }
    }

    if (usageSectionIdx < 0) {
      final hasGuide =
          base.slotsByNavIndex.containsKey(HomeNavIndex.usageGuide);
      outSections.add(
        NavMenuSectionSpec(
          title: systemTitleFallback,
          navIndexes: [
            HomeNavIndex.setting,
            if (hasGuide) HomeNavIndex.usageGuide,
            HomeNavIndex.logout,
          ],
        ),
      );
    }

    return NavMenuSnapshot(sections: outSections, slotsByNavIndex: slots);
  }

  /// สร้างโครงจากแถว [app_menu] หลังตัดรายการที่แอปฝังคงที่แล้ว
  static NavMenuSnapshot _fromFlatRowsCore(List<AppMenuRow> rows) {
    final active = rows.where((r) => r.isActive == 1).toList();
    final byParent = <int?, List<AppMenuRow>>{};
    for (final r in active) {
      byParent.putIfAbsent(r.parentId, () => []).add(r);
    }
    for (final list in byParent.values) {
      list.sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.id.compareTo(b.id);
      });
    }

    final roots = byParent[null] ?? [];
    final sections = <NavMenuSectionSpec>[];
    final slots = <int, NavMenuSlot>{};

    for (final root in roots) {
      final kids = byParent[root.id] ?? [];
      final leaves = kids.where((k) => k.navIndex != null).toList();
      if (leaves.isEmpty) continue;
      sections.add(NavMenuSectionSpec(
        title: root.nameTh,
        navIndexes: leaves.map((k) => k.navIndex!).toList(),
      ));
      for (final leaf in leaves) {
        final perm = leaf.requiredPermission?.trim();
        if (perm == null || perm.isEmpty) continue;
        slots[leaf.navIndex!] = NavMenuSlot(
          navIndex: leaf.navIndex!,
          label: leaf.nameTh,
          icon: iconForKey(leaf.iconKey),
          requiredPermission: perm,
        );
      }
    }

    return NavMenuSnapshot(sections: sections, slotsByNavIndex: slots);
  }

  /// สร้างโครง sidebar / bottom nav จากแถว [app_menu] แบบ flat + เมนูคงที่จากแอป
  static NavMenuSnapshot fromFlatRows(List<AppMenuRow> rows) {
    final filtered =
        rows.where((r) => !_isFixedNavExcludedFromDbTree(r)).toList();
    return _mergeFixedNavSlots(_fromFlatRowsCore(filtered));
  }

  /// ไอคอนเดียวกับเมนูหลัก (drawer / sidebar) สำหรับ [navIndex]
  IconData iconForNavIndex(int navIndex) =>
      slotsByNavIndex[navIndex]?.icon ?? Icons.circle_outlined;
}

class AppMenuLocalDataSource {
  AppMenuLocalDataSource({AppDatabase? db}) : _db = db ?? AppDatabase();

  final AppDatabase _db;

  Future<NavMenuSnapshot> loadSnapshot() async {
    try {
      final database = await _db.database;
      await _ensureEssentialWorkflowRows(database);
      final maps = await database.query('app_menu', orderBy: 'id ASC');
      if (maps.isEmpty) {
        await _restoreDefaultMenu(database);
        return NavMenuSnapshot.fallback();
      }
      final rows = maps.map(AppMenuRow.fromMap).toList();
      final snapshot = NavMenuSnapshot.fromFlatRows(rows);
      if (snapshot.sections.isNotEmpty && snapshot.slotsByNavIndex.isNotEmpty) {
        return snapshot;
      }

      // Self-heal corrupted/incomplete app_menu data (e.g. only section rows).
      await _restoreDefaultMenu(database);
      return NavMenuSnapshot.fallback();
    } catch (_) {
      return NavMenuSnapshot.fallback();
    }
  }

  Future<void> _ensureEssentialWorkflowRows(Database database) async {
    const essentialSlugs = <String>{
      'section_transactions',
      'expense_req',
      'expense',
      'section_approval_reports',
      'approval',
    };
    final rowsBySlug = <String, Map<String, Object?>>{
      for (final row in AppMenuSeedData.sqliteRows())
        if (essentialSlugs.contains(row['slug']?.toString()))
          row['slug']!.toString(): row,
    };
    if (rowsBySlug.isEmpty) return;

    final now = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      int? asInt(Object? value) {
        if (value == null) return null;
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse(value.toString());
      }

      Future<int?> ensureRow(
        String slugKey, {
        int? parentId,
      }) async {
        final row = rowsBySlug[slugKey];
        if (row == null) return null;
        final slug = row['slug']?.toString() ?? '';
        if (slug.isEmpty) return null;
        final existing = await txn.query(
          'app_menu',
          where: 'slug = ?',
          whereArgs: [slug],
          limit: 1,
        );
        if (existing.isEmpty) {
          final insertMap = <String, Object?>{
            ...row,
            if (parentId != null) 'parent_id': parentId,
            'last_modified': now,
          };
          final requestedId = asInt(insertMap['id']);
          if (requestedId != null) {
            final idRows = await txn.query(
              'app_menu',
              columns: ['slug'],
              where: 'id = ?',
              whereArgs: [requestedId],
              limit: 1,
            );
            final idIsUsedByAnotherSlug =
                idRows.isNotEmpty && idRows.first['slug']?.toString() != slug;
            if (idIsUsedByAnotherSlug) {
              insertMap.remove('id');
            }
          }
          await txn.insert(
            'app_menu',
            insertMap,
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          final inserted = await txn.query(
            'app_menu',
            columns: ['id'],
            where: 'slug = ?',
            whereArgs: [slug],
            limit: 1,
          );
          return inserted.isEmpty ? null : asInt(inserted.first['id']);
        }

        final current = existing.first;
        final currentId = asInt(current['id']);
        final patch = <String, Object?>{};
        for (final key in <String>[
          'route_key',
          'required_permission',
          'icon_key',
          'nav_index',
        ]) {
          if (current[key]?.toString() != row[key]?.toString()) {
            patch[key] = row[key];
          }
        }
        final targetParentId = parentId ?? row['parent_id'];
        if (current['parent_id']?.toString() != targetParentId?.toString()) {
          patch['parent_id'] = targetParentId;
        }
        if ((current['is_active'] as int? ?? 1) != 1) {
          patch['is_active'] = 1;
        }
        if (patch.isNotEmpty) {
          patch['last_modified'] = now;
          await txn.update(
            'app_menu',
            patch,
            where: 'slug = ?',
            whereArgs: [slug],
          );
        }
        return currentId;
      }

      final transactionSectionId = await ensureRow('section_transactions');
      final approvalSectionId = await ensureRow('section_approval_reports');

      await ensureRow('expense_req', parentId: transactionSectionId);
      await ensureRow('expense', parentId: transactionSectionId);
      await ensureRow('approval', parentId: approvalSectionId);
    });
  }

  Future<void> _restoreDefaultMenu(Database database) async {
    final rows = AppMenuSeedData.sqliteRows();
    await database.transaction((txn) async {
      await txn.delete('app_menu');
      for (final row in rows) {
        await txn.insert(
          'app_menu',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// แถวทั้งหมดใน [app_menu] (รวมปิดใช้งาน) — หน้าตั้งค่าเมนู
  Future<List<AppMenuRow>> loadAllRowsForEdit() async {
    final database = await _db.database;
    final maps = await database.query('app_menu', orderBy: 'id ASC');
    return maps.map(AppMenuRow.fromMap).toList();
  }

  /// อัปเดตเฉพาะ name_th, sort_order, is_active
  Future<void> applyBulkFieldUpdates(
    List<({int id, String nameTh, int sortOrder, int isActive})> patches,
  ) async {
    if (patches.isEmpty) return;
    final database = await _db.database;
    final ts = DateTime.now().toIso8601String();
    await database.transaction((txn) async {
      for (final p in patches) {
        await txn.update(
          'app_menu',
          {
            'name_th': p.nameTh,
            'sort_order': p.sortOrder,
            'is_active': p.isActive,
            'last_modified': ts,
          },
          where: 'id = ?',
          whereArgs: [p.id],
        );
      }
    });
  }

  /// แทนที่ตารางจาก JSON เซิร์ฟเวอร์ (ลำดับ parent ก่อนลูก — เรียง id)
  Future<void> replaceAllFromServerRows(List<Map<String, dynamic>> raw) async {
    if (raw.isEmpty) return;
    final database = await _db.database;
    final normalized = raw.map(mapRemoteMenuRowToSqlite).toList()
      ..sort((a, b) {
        final pa = a['parent_id'] as int?;
        final pb = b['parent_id'] as int?;
        final ra = pa == null ? 0 : 1;
        final rb = pb == null ? 0 : 1;
        if (ra != rb) return ra.compareTo(rb);
        if (pa != pb) return (pa ?? 0).compareTo(pb ?? 0);
        return (a['id']! as int).compareTo(b['id']! as int);
      });
    await database.transaction((txn) async {
      await txn.delete('app_menu');
      for (final row in normalized) {
        await txn.insert(
          'app_menu',
          row,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}

/// แปลงแถวจาก API เป็น map คอลัมน์ SQLite [app_menu]
Map<String, Object?> mapRemoteMenuRowToSqlite(Map<String, dynamic> m) {
  int asInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  int? asIntNull(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int asBool01(Object? v) {
    if (v is bool) return v ? 1 : 0;
    if (v is num) return v != 0 ? 1 : 0;
    final s = v?.toString().toLowerCase();
    return (s == '1' || s == 'true') ? 1 : 0;
  }

  Object? pick(String snake, String camel) => m[snake] ?? m[camel];

  return <String, Object?>{
    'id': asInt(pick('id', 'id')),
    'parent_id': asIntNull(pick('parent_id', 'parentId')),
    'slug': pick('slug', 'slug')?.toString() ?? '',
    'name_th': pick('name_th', 'nameTh')?.toString() ?? '',
    'name_en': pick('name_en', 'nameEn')?.toString() ?? '',
    'route_key': pick('route_key', 'routeKey')?.toString(),
    'required_permission':
        pick('required_permission', 'requiredPermission')?.toString(),
    'icon_key': pick('icon_key', 'iconKey')?.toString(),
    'sort_order': asInt(pick('sort_order', 'sortOrder') ?? 0),
    'nav_index': asIntNull(pick('nav_index', 'navIndex')),
    'is_active': asBool01(pick('is_active', 'isActive')),
    'last_modified': pick('last_modified', 'lastModified')?.toString() ??
        DateTime.now().toIso8601String(),
  };
}
