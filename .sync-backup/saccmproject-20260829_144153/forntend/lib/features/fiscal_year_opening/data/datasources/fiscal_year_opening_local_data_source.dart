import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/local_data_source/app_database.dart';
import '../models/fiscal_year_opening_row.dart';

/// Local data source (SQLite mirror) ของยอดยกมาต้นปีงบประมาณ
class FiscalYearOpeningLocalDataSource {
  static const String _table = 'fiscal_year_opening';

  Future<Database> get _db async => AppDatabase().database;

  /// ดึงรายการยอดยกมาของปีงบประมาณ — เติม slot ที่ยังไม่มีให้เป็น 0 ตาม 7×3 grid
  Future<List<FiscalYearOpeningRow>> getGrid(String fiscalYear) async {
    final db = await _db;
    final rows = await db.query(
      _table,
      where: 'fiscal_year = ?',
      whereArgs: [fiscalYear],
    );

    final byKey = <String, Map<String, Object?>>{};
    for (final r in rows) {
      final key = '${r['bucket']}::${r['pocket']}';
      byKey[key] = r;
    }

    final out = <FiscalYearOpeningRow>[];
    for (final bucket in FiscalYearOpeningConst.buckets) {
      for (final pocket in FiscalYearOpeningConst.pockets) {
        final key = '$bucket::$pocket';
        final r = byKey[key];
        if (r != null) {
          out.add(FiscalYearOpeningRow(
            id: r['id']?.toString(),
            fiscalYear: r['fiscal_year']?.toString() ?? fiscalYear,
            bucket: bucket,
            pocket: pocket,
            openingAmount:
                (r['opening_amount'] as num?)?.toDouble() ?? 0,
            remark: r['remark']?.toString(),
            source: r['source']?.toString() ?? 'manual',
            use: r['use']?.toString() ?? 'Y',
          ));
        } else {
          out.add(FiscalYearOpeningRow(
            fiscalYear: fiscalYear,
            bucket: bucket,
            pocket: pocket,
            openingAmount: 0,
          ));
        }
      }
    }
    return out;
  }

  /// ยอดยกมาแยก bucket → pocket (cash/bank/agency) สำหรับรายงานหน้า 34
  Future<Map<String, Map<String, double>>> loadMapForFiscalYear(
    String fiscalYear,
  ) async {
    final grid = await getGrid(fiscalYear);
    final out = <String, Map<String, double>>{};
    for (final r in grid) {
      out.putIfAbsent(
        r.bucket,
        () => {'cash': 0, 'bank': 0, 'agency': 0},
      );
      out[r.bucket]![r.pocket] = r.openingAmount;
    }
    return out;
  }

  /// upsert ทั้ง grid ของปี — เขียนทับด้วย transaction เพื่อ atomic
  Future<void> upsertGrid(
    String fiscalYear,
    List<FiscalYearOpeningRow> rows,
  ) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      for (final r in rows) {
        if (r.fiscalYear != fiscalYear) continue;
        final existing = await txn.query(
          _table,
          where: 'fiscal_year = ? AND bucket = ? AND pocket = ?',
          whereArgs: [fiscalYear, r.bucket, r.pocket],
          limit: 1,
        );
        final values = <String, Object?>{
          'fiscal_year': fiscalYear,
          'bucket': r.bucket,
          'pocket': r.pocket,
          'opening_amount': r.openingAmount,
          'remark': r.remark,
          'source': r.source,
          'use': r.use,
          'updated': now,
          'last_modified': now,
          'synced': 0,
        };
        if (existing.isEmpty) {
          final id = r.id ??
              'fyo_${fiscalYear}_${r.bucket}_${r.pocket}'
                  .replaceAll(' ', '_');
          await txn.insert(
            _table,
            {
              'id': id,
              'created': now,
              ...values,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } else {
          await txn.update(
            _table,
            values,
            where: 'fiscal_year = ? AND bucket = ? AND pocket = ?',
            whereArgs: [fiscalYear, r.bucket, r.pocket],
          );
        }
      }
    });
  }

  /// แทนที่ทั้ง grid จากข้อมูลที่ดึงมาจาก remote (sync down)
  Future<void> replaceGridFromRemote(
    String fiscalYear,
    List<FiscalYearOpeningRow> rows,
  ) async {
    final db = await _db;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        _table,
        where: 'fiscal_year = ?',
        whereArgs: [fiscalYear],
      );
      for (final r in rows) {
        final id = r.id ??
            'fyo_${fiscalYear}_${r.bucket}_${r.pocket}'.replaceAll(' ', '_');
        await txn.insert(
          _table,
          {
            'id': id,
            'fiscal_year': fiscalYear,
            'bucket': r.bucket,
            'pocket': r.pocket,
            'opening_amount': r.openingAmount,
            'remark': r.remark,
            'source': r.source,
            'use': r.use,
            'created': now,
            'updated': now,
            'last_modified': now,
            'synced': 1,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }
}
