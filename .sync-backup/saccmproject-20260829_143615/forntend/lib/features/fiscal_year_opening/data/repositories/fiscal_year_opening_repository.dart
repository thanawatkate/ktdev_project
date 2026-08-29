import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:saccm/features/license/license_mode.dart';
import '../datasources/fiscal_year_opening_local_data_source.dart';
import '../datasources/fiscal_year_opening_remote_data_source.dart';
import '../models/fiscal_year_opening_row.dart';

/// Repository — local-first + background sync ตาม TEAM_RULES §4.2
class FiscalYearOpeningRepository {
  final FiscalYearOpeningLocalDataSource _local;
  final FiscalYearOpeningRemoteDataSource _remote;

  FiscalYearOpeningRepository({
    FiscalYearOpeningLocalDataSource? local,
    FiscalYearOpeningRemoteDataSource? remote,
  })  : _local = local ?? FiscalYearOpeningLocalDataSource(),
        _remote = remote ?? FiscalYearOpeningRemoteDataSource();

  /// คืนค่า rows จาก SQLite ก่อน — สำหรับ UI
  Future<List<FiscalYearOpeningRow>> loadLocal(String fiscalYear) {
    return _local.getGrid(fiscalYear);
  }

  /// ดึงจาก remote แล้วบันทึก local — เรียกหลังจาก loadLocal เพื่อรีเฟรชเงียบ ๆ
  Future<void> syncFromRemote(String fiscalYear) async {
    if (!await LicenseMode.canSyncOnline()) return;
    final rows = await _remote.getGrid(fiscalYear);
    await _local.replaceGridFromRemote(fiscalYear, rows);
  }

  /// ดึงยอดที่ระบบเสนอจาก local: ใช้ยอดปีงบก่อนหน้าเป็นฐาน ไม่อ่าน server ใน UI path
  Future<List<FiscalYearOpeningRow>> fetchSuggested(String fiscalYear) async {
    final year = int.tryParse(fiscalYear);
    if (year == null) return _local.getGrid(fiscalYear);
    final previous = await _local.getGrid((year - 1).toString());
    return previous
        .map(
          (row) => FiscalYearOpeningRow(
            fiscalYear: fiscalYear,
            bucket: row.bucket,
            pocket: row.pocket,
            openingAmount: row.openingAmount,
            source: 'previous_year_local',
            use: row.use,
          ),
        )
        .toList();
  }

  /// บันทึก — local ก่อน แล้ว push ไป remote (background)
  Future<void> saveGrid({
    required String token,
    required String fiscalYear,
    required List<FiscalYearOpeningRow> rows,
  }) async {
    await _local.upsertGrid(fiscalYear, rows);
    if (!await LicenseMode.canSyncOnline()) return;
    unawaited(() async {
      try {
        await _remote.upsertGrid(
          token: token,
          fiscalYear: fiscalYear,
          rows: rows,
        );
      } catch (e) {
        debugPrint('FiscalYearOpening remote sync failed: $e');
      }
    }());
  }

  Future<void> copyFromPrevious({
    required String? token,
    required String fiscalYear,
  }) async {
    final rows = await fetchSuggested(fiscalYear);
    await _local.upsertGrid(fiscalYear, rows);
    if (!await LicenseMode.canSyncOnline() || token == null || token.isEmpty) {
      return;
    }
    unawaited(() async {
      try {
        await _remote.copyFromPrevious(token: token, fiscalYear: fiscalYear);
        await syncFromRemote(fiscalYear);
      } catch (e) {
        debugPrint('FiscalYearOpening copy sync failed: $e');
      }
    }());
  }
}
