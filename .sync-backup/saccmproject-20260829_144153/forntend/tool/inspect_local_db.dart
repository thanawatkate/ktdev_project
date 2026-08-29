// ignore_for_file: avoid_print
//
// ดึงข้อมูลจาก SQLite localdb (saccm.db) มาแสดงในเทอร์มินัล
//
// รัน (จากโฟลเดอร์ forntend):
//   dart run tool/inspect_local_db.dart
//   dart run tool/inspect_local_db.dart --db "C:\path\to\saccm.db"
//   dart run tool/inspect_local_db.dart --tables income,pending_requests --limit 30
//   dart run tool/inspect_local_db.dart --tables budget_source_master,money_group --limit 30
//   dart run tool/inspect_local_db.dart --no-open-folder   (ไม่เปิด Explorer/Finder)
//
// ลำดับหาไฟล์ db อัตโนมัติ: SACCM_DB_PATH → .dart_tool/.../saccm.db (cwd) → Documents/databases/saccm.db
// หลังแสดงข้อมูลจะเปิดตัวจัดการไฟล์ไปที่ไฟล์ db (Windows: เลือกไฟล์, macOS: แสดงใน Finder, Linux: เปิดโฟลเดอร์)
//

import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main(List<String> args) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final opts = _parseArgs(args);
  final dbPath = opts.dbPath ?? _resolveDbPath();

  if (!File(dbPath).existsSync()) {
    stderr.writeln('ไม่พบไฟล์: $dbPath');
    stderr.writeln('');
    stderr.writeln('ลองระบุ path เอง:');
    stderr.writeln('  dart run tool/inspect_local_db.dart --db "<path>/saccm.db"');
    stderr.writeln('หรือตั้งค่า SACCM_DB_PATH');
    exitCode = 1;
    return;
  }

  print('ใช้ไฟล์: $dbPath\n');

  final db = await databaseFactory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(readOnly: true, singleInstance: false),
  );

  try {
    late final List<String> tables;
    if (opts.tables != null && opts.tables!.isNotEmpty) {
      tables = opts.tables!;
    } else {
      tables = await _listUserTables(db);
      tables.sort();
    }

    if (tables.isEmpty) {
      print('ไม่พบตาราง');
    } else {
      for (final name in tables) {
        await _dumpTable(db, name, opts.limit);
      }
    }
  } finally {
    await db.close();
  }

  if (opts.openFolder) {
    await _openFileManagerToDb(dbPath);
  }
}

class _Opts {
  _Opts({
    this.dbPath,
    this.tables,
    this.limit = 50,
    this.openFolder = true,
  });

  final String? dbPath;
  final List<String>? tables;
  final int limit;
  final bool openFolder;
}

_Opts _parseArgs(List<String> args) {
  String? dbPath;
  List<String>? tables;
  var limit = 50;
  var openFolder = true;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--db' && i + 1 < args.length) {
      dbPath = args[++i];
    } else if (a == '--tables' && i + 1 < args.length) {
      tables = args[++i]
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else if (a == '--limit' && i + 1 < args.length) {
      limit = int.tryParse(args[++i]) ?? 50;
    } else if (a == '--no-open-folder') {
      openFolder = false;
    } else if (a == '--help' || a == '-h') {
      stdout.writeln(_usage);
      exit(0);
    }
  }

  return _Opts(
    dbPath: dbPath,
    tables: tables,
    limit: limit.clamp(1, 5000),
    openFolder: openFolder,
  );
}

const _usage = '''
inspect_local_db — แสดงข้อมูลจาก saccm.db (อ่านอย่างเดียว)

  dart run tool/inspect_local_db.dart [options]

ตัวเลือก:
  --db <path>           ไฟล์ SQLite (ค่าเริ่มต้น: หา saccm.db อัตโนมัติ)
  --tables a,b,c        เฉพาะตารางที่ระบุ (ค่าเริ่มต้น: ทุกตารางผู้ใช้)
  --limit <n>           จำนวนแถวสูงสุดต่อตาราง (ค่าเริ่มต้น 50, สูงสุด 5000)
  --no-open-folder      ไม่เปิด Explorer / Finder / โฟลเดอร์หลังรัน
  -h, --help            แสดงข้อความนี้
''';

String _resolveDbPath() {
  final env = Platform.environment['SACCM_DB_PATH']?.trim();
  if (env != null && env.isNotEmpty) return env;

  final cwd = Directory.current.path;
  final sep = Platform.pathSeparator;
  String j(String a, String b, [String? c, String? d, String? e]) {
    var s = '$a$sep$b';
    if (c != null) s = '$s$sep$c';
    if (d != null) s = '$s$sep$d';
    if (e != null) s = '$s$sep$e';
    return s;
  }

  final candidates = <String>[
    j(cwd, '.dart_tool', 'sqflite_common_ffi', 'databases', 'saccm.db'),
    if (Platform.isWindows)
      j(Platform.environment['USERPROFILE'] ?? '', 'Documents', 'databases', 'saccm.db')
    else
      j(Platform.environment['HOME'] ?? '', 'Documents', 'databases', 'saccm.db'),
  ];

  for (final c in candidates) {
    if (c.isEmpty) continue;
    if (File(c).existsSync()) return c;
  }

  return candidates.first;
}

Future<List<String>> _listUserTables(Database db) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  return rows.map((r) => r['name'] as String).toList();
}

Future<void> _dumpTable(Database db, String table, int limit) async {
  final safe = _quoteIdent(table);
  final countRows =
      await db.rawQuery('SELECT COUNT(*) AS c FROM $safe');
  final total = countRows.first['c'] as int? ?? 0;

  final data = await db.rawQuery('SELECT * FROM $safe LIMIT ?', [limit]);

  print('════════════════════════════════════════════════════════════');
  print('ตาราง: $table   (ทั้งหมด $total แถว, แสดง ${data.length})');
  print('════════════════════════════════════════════════════════════');

  if (data.isEmpty) {
    print('(ไม่มีแถว)\n');
    return;
  }

  const encoder = JsonEncoder.withIndent('  ');
  for (var i = 0; i < data.length; i++) {
    print('--- แถว ${i + 1} ---');
    print(encoder.convert(data[i]));
  }
  if (total > data.length) {
    print('… ตัดเหลือ $limit แถว (--limit เพื่อเพิ่ม)');
  }
  print('');
}

/// จำกัดตัวระบุตารางเป็นชื่อที่ปลอดภัย (อักษร ตัวเลข _)
String _quoteIdent(String name) {
  if (!RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(name)) {
    throw FormatException('ชื่อตารางไม่ถูกต้อง: $name');
  }
  return '"$name"';
}

/// เปิดตัวจัดการไฟล์ไปที่ไฟล์ db (Windows เลือกไฟล์, macOS แสดงใน Finder, Linux เปิดโฟลเดอร์)
Future<void> _openFileManagerToDb(String dbPath) async {
  final file = File(dbPath);
  if (!await file.exists()) return;

  final abs = file.absolute.path;

  try {
    if (Platform.isWindows) {
      final p = abs.replaceAll('/', r'\');
      final arg = p.contains(' ') ? '/select,"$p"' : '/select,$p';
      await Process.start(
        'explorer',
        [arg],
        mode: ProcessStartMode.detached,
      );
    } else if (Platform.isMacOS) {
      await Process.start(
        'open',
        ['-R', abs],
        mode: ProcessStartMode.detached,
      );
    } else {
      await Process.start(
        'xdg-open',
        [file.parent.absolute.path],
        mode: ProcessStartMode.detached,
      );
    }
    print('เปิดตัวจัดการไฟล์ไปที่ไฟล์ db แล้ว');
  } catch (e) {
    stderr.writeln('ไม่สามารถเปิดโฟลเดอร์/ตัวเลือกไฟล์ได้: $e');
  }
}
