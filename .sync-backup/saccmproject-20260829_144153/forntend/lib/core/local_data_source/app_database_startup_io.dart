import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';

/// Key ใน SharedPreferences — คัดลอกไฟล์สำรองไปแล้ว รอแทนที่ saccm.db ตอนเปิดแอปรอบถัดไป
const String kPendingSaccmDbRestorePathKey = 'pending_saccm_db_restore_path';

/// เรียกจาก [main] ก่อน [ServiceLocator.init] — แทนที่ `saccm.db` จากไฟล์ที่ผู้ใช้เลือกกู้คืน
Future<void> applyPendingSaccmDbRestoreIfAny() async {
  final prefs = await SharedPreferences.getInstance();
  final pending = prefs.getString(kPendingSaccmDbRestorePathKey);
  if (pending == null || pending.isEmpty) return;

  final src = File(pending);
  if (!await src.exists()) {
    await prefs.remove(kPendingSaccmDbRestorePathKey);
    return;
  }

  final dbFolder = await getDatabasesPath();
  final target = File('$dbFolder/${AppDatabase.dbName}');
  try {
    if (await target.exists()) {
      await target.delete();
    }
    await src.copy(target.path);
  } finally {
    try {
      if (await src.exists()) await src.delete();
    } catch (_) {}
    await prefs.remove(kPendingSaccmDbRestorePathKey);
  }
}
