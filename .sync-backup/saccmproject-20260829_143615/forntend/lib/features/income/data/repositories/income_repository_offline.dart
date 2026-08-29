import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:saccm/core/error/failures.dart';
import 'package:saccm/core/error/party_tax_id_duplicate_exception.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/income_local_data_source.dart';
import 'package:saccm/core/utils/either.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/income/data/models/income_model.dart';
import 'package:saccm/features/income/domain/entities/income_entity.dart';
import 'package:saccm/features/income/data/models/lookup_item_model.dart';
import 'package:saccm/features/income/data/datasources/income_remote_data_source.dart';
import 'package:saccm/features/income/domain/rules/income_money_domain_rule.dart';
import 'package:saccm/features/income/domain/entities/lookup_item.dart';
import 'package:saccm/features/income/domain/repositories/income_repository.dart'
    as domain;
import 'package:saccm/features/license/license_mode.dart';
import 'package:sqflite/sqflite.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// Offline-First Income Repository
///
/// หลักการ: Local DB คือ Source of Truth เสมอ
///   • READ  → คืนจาก SQLite เสมอ (lookup/party/งบประมาณ) + ซิงก์จาก server แบบเบื้องหลังเมื่อออนไลน์
///   • WRITE → บันทึก local ก่อน (synced=false) + queue sync ทันที
///             ถ้า online จะ trigger sync เลย, ถ้า offline รอจนกว่าจะ online
/// ─────────────────────────────────────────────────────────────────────────────
class IncomeRepository implements domain.IncomeRepository {
  final IncomeRemoteDataSource _remoteDataSource;
  final IncomeLocalDataSource _localDataSource;
  final AuditLogLocalDataSource? _auditLogLocalDataSource;
  final NetworkInfoService _networkInfo;
  final SyncService _syncService;

  IncomeRepository({
    required IncomeRemoteDataSource remoteDataSource,
    required IncomeLocalDataSource localDataSource,
    AuditLogLocalDataSource? auditLogLocalDataSource,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _auditLogLocalDataSource = auditLogLocalDataSource,
        _networkInfo = networkInfo,
        _syncService = syncService;

  Future<String> _inferMoneyDomainForHeaderIncomeType(
      String incomeTypeLookupId) async {
    final rows = await _localDataSource.db.query(
      'income_type',
      columns: ['code'],
      where: 'id = ?',
      whereArgs: [incomeTypeLookupId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final code = rows.first['code']?.toString() ?? '';
      if (code.isNotEmpty) {
        return IncomeMoneyDomainRule.inferFromCode(code);
      }
    }
    return IncomeMoneyDomainRule.inferFromLookupId(incomeTypeLookupId);
  }

  // ─── READ: คืน local ทันที ─────────────────────────────────────────────────

  @override
  Future<Either<Failure, List<IncomeEntity>>> getIncomeList() async {
    try {
      return Right(await _localDataSource.getAllIncomes());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// ดึง income ตาม id จาก local
  Future<IncomeEntity?> getIncomeById(String id) =>
      _localDataSource.getIncomeById(id);

  @override
  Future<Either<Failure, List<LookupItem>>> getMoneyTypes() async {
    try {
      final local =
          await _localDataSource.db.query('money_type', orderBy: 'name ASC');
      return Right(local
          .map((e) => LookupItemModel(
                id: e['id']?.toString() ?? '',
                name: e['name']?.toString() ?? '',
              ))
          .toList());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getIncomeTypes() async {
    try {
      final local = await _localDataSource.db.query(
        'income_type',
        where: '(code IS NULL OR code NOT IN (?, ?))',
        whereArgs: const ['GUAR-01', 'WHT-01'],
        orderBy: 'name ASC',
      );
      return Right(local
          .map((e) => LookupItemModel(
                id: e['id']?.toString() ?? '',
                code: e['code']?.toString(),
                name: e['name']?.toString() ?? '',
              ))
          .toList());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<void> _backgroundPullBudgetSourcesFromRemote() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final remote = await _remoteDataSource.getBudgetSources();
      final batch = _localDataSource.db.batch();
      final now = DateTime.now().toIso8601String();
      for (final item in remote) {
        final linkedFundCategories =
            (item.refFundCategories ?? const <String>[])
                .where((id) => id.trim().isNotEmpty)
                .toSet()
                .toList();
        final fallbackRefFundCategory = (item.refFundCategory ?? '').trim();
        if (linkedFundCategories.isEmpty &&
            fallbackRefFundCategory.isNotEmpty) {
          linkedFundCategories.add(fallbackRefFundCategory);
        }
        batch.insert(
          'budget_source_master',
          {
            'id': item.id,
            'code': item.id,
            'name': item.name,
            'budget_type': 'unknown',
            'refFundCategory': item.refFundCategory,
            'description': '',
            'synced': 1,
            'lastModified': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        for (final refFundCategory in linkedFundCategories) {
          batch.insert(
            'income_type_budget_source_map',
            {
              'id': 'itbsm_${refFundCategory}_${item.id}',
              'refIncomeType': refFundCategory,
              'refBudgetSourceMaster': item.id,
              'synced': 1,
              'lastModified': now,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
        batch.insert(
          'budget_source_budget',
          {
            'id': item.id,
            'refBudgetSourceMaster': item.id,
            'fiscal_year': DateTime.now().year.toString(),
            'budget_amount': 0,
            'brought_forward_amount': 0,
            'used_amount': 0,
            'synced': 1,
            'lastModified': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await batch.commit(noResult: true);
    } catch (_) {}
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getBudgetSources() async {
    try {
      final items = await _localDataSource.getBudgetSourceLookups();
      unawaited(_backgroundPullBudgetSourcesFromRemote());
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getBudgetSourcesForIncomeType(
    String incomeTypeId,
  ) async {
    try {
      final items = await _localDataSource
          .getBudgetSourceLookupsForIncomeType(incomeTypeId);
      unawaited(_backgroundPullBudgetSourcesFromRemote());
      return Right(items);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, LookupItem?>> getBudgetSourceById(
    String budgetSourceId,
  ) async {
    try {
      return Right(
          await _localDataSource.getBudgetSourceLookupById(budgetSourceId));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<List<LookupItemModel>> _distinctPartyNamesFromLocalIncome() async {
    final localRows = await _localDataSource.db.rawQuery('''
      SELECT DISTINCT partyName
      FROM income
      WHERE partyName IS NOT NULL AND TRIM(partyName) <> ''
      ORDER BY partyName ASC
    ''');
    return localRows
        .map((e) => LookupItemModel(
              id: e['partyName']?.toString() ?? '',
              name: e['partyName']?.toString() ?? '',
            ))
        .where((e) => e.name.isNotEmpty)
        .toList();
  }

  static bool _partyMapRowIsActivePayerCapable(Map<String, dynamic> row) {
    final role = (row['role'] ?? 'both').toString().toLowerCase().trim();
    if (role != 'payer' && role != 'both') return false;
    final ia = row['isactive'];
    return ia == true || ia == 1 || ia == '1';
  }

  List<LookupItemModel> _partyRowMapsToLookupItems(
    List<Map<String, dynamic>> rows,
  ) {
    final seen = <String>{};
    final out = <LookupItemModel>[];
    for (final r in rows) {
      final name = (r['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      final k = name.toLowerCase();
      if (seen.contains(k)) continue;
      seen.add(k);
      out.add(LookupItemModel(
        id: (r['id'] ?? name).toString(),
        name: name,
      ));
    }
    return out;
  }

  /// แถวผู้จ่ายจากตาราง `party` + ชื่อจาก income ที่ยังไม่มีใน master
  Future<List<Map<String, dynamic>>> _buildLocalPayerPartyRowMaps() async {
    final db = _localDataSource.db;
    // รัน 2 queries พร้อมกัน — ลดเวลารอรวม
    final results = await Future.wait([
      db.query('party', orderBy: 'name ASC'),
      _distinctPartyNamesFromLocalIncome(),
    ]);
    final partyRows = results[0] as List<Map<String, dynamic>>;
    final incomeNames = results[1] as List<LookupItemModel>;

    final fromMaster = <Map<String, dynamic>>[];
    final nameLower = <String>{};

    for (final pr in partyRows) {
      final m = Map<String, dynamic>.from(pr);
      if (!_partyMapRowIsActivePayerCapable(m)) continue;
      final name = (m['name'] ?? '').toString().trim();
      if (name.isEmpty) continue;
      fromMaster.add({
        'id': m['id']?.toString() ?? '',
        'name': name,
        'role': (m['role'] ?? 'both').toString(),
        'isactive': true,
      });
      nameLower.add(name.toLowerCase());
    }

    final synthetic = <Map<String, dynamic>>[];
    for (final li in incomeNames) {
      final n = li.name.trim();
      if (n.isEmpty) continue;
      if (nameLower.contains(n.toLowerCase())) continue;
      nameLower.add(n.toLowerCase());
      synthetic.add(<String, dynamic>{
        'id': n,
        'name': n,
        'role': 'both',
        'isactive': true,
      });
    }
    return [...fromMaster, ...synthetic];
  }

  Future<List<LookupItemModel>> _localPartyLookupMerged() async {
    final rows = await _buildLocalPayerPartyRowMaps();
    return _partyRowMapsToLookupItems(rows);
  }

  @override
  Future<void> cachePartyMasterRowsFromServer(
          List<Map<String, dynamic>> rows) =>
      _persistPartyRowsFromApi(rows);

  @override
  Future<void> refreshPartyMasterCacheFromServer() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final parties = await _remoteDataSource.fetchPartiesAllPages(
        activeOnly: false,
      );
      await _persistPartyRowsFromApi(parties);
    } catch (_) {
      // ไม่ throw — UI อ่านจาก localdb อยู่แล้ว
    }
  }

  Future<void> _persistPartyRowsFromApi(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = _localDataSource.db;

    // Collect IDs of locally modified records (synced=0) so we don't
    // overwrite pending edits/creates with stale server data.
    final pendingRows = await db.query(
      'party',
      columns: ['id'],
      where: 'synced = ?',
      whereArgs: [0],
    );
    final pendingIds =
        pendingRows.map((r) => (r['id'] ?? '').toString()).toSet();

    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      final name = (r['name'] ?? '').toString().trim();
      if (id.isEmpty || name.isEmpty) continue;
      // Skip records that have unsent local changes to avoid reverting edits.
      if (pendingIds.contains(id)) continue;
      final active = r['isactive'] == true ||
          r['isactive'] == 1 ||
          r['isactive']?.toString() == '1';
      batch.insert(
        'party',
        {
          'id': id,
          'name': name,
          'role': (r['role'] ?? 'both').toString().toLowerCase(),
          'phone': r['phone']?.toString(),
          'taxid': (r['taxid'] ?? r['taxId'])?.toString(),
          'remark': r['remark']?.toString(),
          'isactive': active ? 1 : 0,
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getPartiesFromLocalIncome() async {
    try {
      return Right(await _localPartyLookupMerged());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getPayerPartyRowsLocalForPicker() async {
    try {
      return Right(await _buildLocalPayerPartyRowMaps());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<LookupItem>>> getParties() async {
    try {
      final localLookup = await _localPartyLookupMerged();
      unawaited(refreshPartyMasterCacheFromServer());
      return Right(localLookup);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// คำนวณเลขเอกสารจากรูปแบบใน doc_group เสมอ
  /// เพื่อให้ตรง format ที่ระบบกำหนด แม้ใช้งาน offline
  @override
  Future<Either<Failure, String>> getDocNo({
    required String tableName,
    required String docDate,
  }) async {
    try {
      final db = _localDataSource.db;
      return await db.transaction((txn) async {
        final date = DateTime.tryParse(docDate) ?? DateTime.now();
        final cfg = await txn.query(
          'doc_group',
          columns: ['rungroup', 'docnoformat'],
          where: 'tablename = ?',
          whereArgs: [tableName],
          limit: 1,
        );

        final rungroup = cfg.isEmpty
            ? 'INC'
            : (cfg.first['rungroup']?.toString().trim().isNotEmpty == true
                ? cfg.first['rungroup'].toString()
                : 'INC');
        final rawFormat = cfg.isEmpty
            ? '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}'
            : (cfg.first['docnoformat']?.toString().trim().isNotEmpty == true
                ? cfg.first['docnoformat'].toString()
                : '{RUNGROUP}-{YYYY}{MM}{DD}-{RUN4}');

        const marker = '__RUN__';
        final baseWithMarker = _resolveFormat(
          format: rawFormat,
          rungroup: rungroup,
          date: date,
          runText: marker,
        );
        final escaped =
            RegExp.escape(baseWithMarker).replaceAll(marker, r'(\d+)');
        final regex = RegExp('^$escaped\$');
        final likePrefix = '${baseWithMarker.split(marker).first}%';
        final docs = await txn.query(
          tableName,
          columns: ['docno'],
          where: likePrefix.length > 1 ? 'docno LIKE ?' : null,
          whereArgs: likePrefix.length > 1 ? [likePrefix] : null,
        );

        var maxRun = 0;
        for (final row in docs) {
          final doc = row['docno']?.toString() ?? '';
          final m = regex.firstMatch(doc);
          if (m == null) continue;
          final run = int.tryParse(m.group(1) ?? '') ?? 0;
          if (run > maxRun) maxRun = run;
        }

        final runNumber = maxRun + 1;
        final runWidth = _runWidth(rawFormat);
        final runText = runNumber.toString().padLeft(runWidth, '0');
        return Right(_resolveFormat(
          format: rawFormat,
          rungroup: rungroup,
          date: date,
          runText: runText,
        ));
      });
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>>
      getAvailableReceiptBooks() async {
    try {
      return Right(await _localDataSource.listAvailableReceiptBooks());
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getSuggestedNextReceiptNo(
    String bookId,
  ) async {
    try {
      return Right(await _localDataSource.suggestedNextReceiptNo(bookId));
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  int _runWidth(String format) {
    final m = RegExp(r'\{RUN(\d+)\}').firstMatch(format);
    if (m != null) return int.tryParse(m.group(1) ?? '') ?? 4;
    return 4;
  }

  String _resolveFormat({
    required String format,
    required String rungroup,
    required DateTime date,
    required String runText,
  }) {
    final yyyy = date.year.toString().padLeft(4, '0');
    final yy = (date.year % 100).toString().padLeft(2, '0');
    final fiscalYear = _fiscalYearBuddhist(date);
    final mm = date.month.toString().padLeft(2, '0');
    final dd = date.day.toString().padLeft(2, '0');

    var out = format
        .replaceAll('{RUNGROUP}', rungroup)
        .replaceAll('{RG}', rungroup)
        .replaceAll('{FISCAL_YEAR}', fiscalYear)
        .replaceAll('{FY}', fiscalYear)
        .replaceAll('{YYYY}', yyyy)
        .replaceAll('{YY}', yy)
        .replaceAll('{MM}', mm)
        .replaceAll('{DD}', dd);
    out = out.replaceAll(RegExp(r'\{RUN\d*\}'), runText);
    if (!out.contains(runText)) {
      out = '$out-$runText';
    }
    return out;
  }

  String _fiscalYearBuddhist(DateTime date) {
    final year = date.month >= 10 ? date.year + 544 : date.year + 543;
    return year.toString();
  }

  // ─── WRITE: local-first + queue ────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> createIncome({
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required String refMoneyType,
    required String refIncomeType,
    required String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? refBankAccount,
    String? receiptBookId,
    String? receiptNo,
    bool bumpBudgetSourceBudgetAmount = true,
    String docStatus = 'posted',
  }) async {
    try {
      var resolvedRefParty = refParty?.trim();
      if (resolvedRefParty == null || resolvedRefParty.isEmpty) {
        resolvedRefParty = await _resolveLocalPartyIdByName(partyName);
      }

      final incomeId = '${docno}_${DateTime.now().millisecondsSinceEpoch}';
      final incomeSubHasRemark = await _incomeSubHasRemarkColumn();
      final incomeSubHasDetail = await _incomeSubHasDetailColumn();
      final moneyDomain =
          await _inferMoneyDomainForHeaderIncomeType(refIncomeType);
      final effectiveDocStatus =
          docStatus.trim().isEmpty ? 'posted' : docStatus.trim();
      final amt = sqliteMoneyToDouble(amount);
      final bankReferenceValue = bankReference?.trim() ?? '';

      final bookIdTrim = receiptBookId?.trim();
      final receiptNoTrim = receiptNo?.trim() ?? '';
      final wantsReceipt = bookIdTrim != null &&
          bookIdTrim.isNotEmpty &&
          receiptNoTrim.isNotEmpty;

      if (wantsReceipt) {
        final receiptErr = await _validateReceiptForCreate(
          bookId: bookIdTrim,
          receiptNo: receiptNoTrim,
        );
        if (receiptErr != null) return Left(CacheFailure(message: receiptErr));
      }

      await _localDataSource.db.transaction((txn) async {
        await _localDataSource.saveIncome(
          IncomeModel(
            id: incomeId,
            docno: docno,
            docdate: docdate,
            amount: amount,
            detail: detail,
            remark: remark,
            bankReference:
                bankReferenceValue.isNotEmpty ? bankReferenceValue : null,
            created: DateTime.now().toIso8601String(),
            refBudgetSource: refBudgetSource,
            refParty: resolvedRefParty,
            partyName: partyName,
            refMoneyType: refMoneyType,
            refBankAccount: refBankAccount?.trim().isNotEmpty == true
                ? refBankAccount!.trim()
                : null,
            docStatus: effectiveDocStatus,
            moneyDomain: moneyDomain,
          ),
          synced: false,
          executor: txn,
        );

        final nowIso = DateTime.now().toIso8601String();
        for (var i = 0; i < subData.length; i++) {
          final sub = subData[i];
          final subRow = <String, Object?>{
            'id': '${incomeId}_sub_$i',
            'refIncome': incomeId,
            'amount': sqliteMoneyToDouble(sub['amount']),
            'refIncomeType': sub['refincometype']?.toString(),
            'refMoneyType': sub['refmoneytype']?.toString() ??
                sub['refMoneyType']?.toString() ??
                refMoneyType,
            'synced': 0,
            'lastModified': nowIso,
          };
          if (incomeSubHasRemark) {
            subRow['remark'] = sub['remark']?.toString() ?? '';
          }
          if (incomeSubHasDetail) {
            subRow['detail'] = sub['detail']?.toString() ?? '';
          }
          await txn.insert(
            'income_sub',
            subRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }

        if (bumpBudgetSourceBudgetAmount &&
            refBudgetSource != null &&
            refBudgetSource.trim().isNotEmpty &&
            amt > 0) {
          await txn.rawUpdate(
            '''
            UPDATE budget_source_budget
            SET budget_amount = budget_amount + ?,
                lastModified = ?
            WHERE id = ?
            ''',
            [amt, nowIso, refBudgetSource],
          );
        }

        if (wantsReceipt) {
          final issueId =
              'ri_${incomeId}_${DateTime.now().microsecondsSinceEpoch}';
          await txn.insert(
            'receipt_issue',
            {
              'id': issueId,
              'ref_book': bookIdTrim,
              'receipt_no': receiptNoTrim,
              'issued_at': nowIso,
              'issued_to': partyName,
              'amount': amt,
              'issue_status': 'used',
              'remark': docno,
              'ref_income': incomeId,
              'created': nowIso,
              'synced': 0,
              'last_modified': nowIso,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      await _syncService.addPendingRequest(
        id: 'income_create_$incomeId',
        method: 'POST',
        endpoint: '${baseurl}income',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          if (bankReferenceValue.isNotEmpty)
            'bank_reference': bankReferenceValue,
          'partyname': partyName,
          if (resolvedRefParty != null && resolvedRefParty.isNotEmpty)
            'refparty': resolvedRefParty,
          'refuser': refUser,
          'refmoneytype': refMoneyType,
          'refincometype': refIncomeType,
          if (refBudgetSource != null && refBudgetSource.isNotEmpty)
            'refbudgetsource': refBudgetSource,
          if (refBankAccount != null && refBankAccount.trim().isNotEmpty)
            'refbankaccount': refBankAccount.trim(),
          'subdata': jsonEncode(subData),
          'money_domain': moneyDomain,
          'doc_status': effectiveDocStatus,
        }),
      );

      await _auditLogLocalDataSource?.logEvent(
        module: 'income',
        action: 'create',
        entityId: incomeId,
        payload: {
          'docno': docno,
          'amount': amount,
        },
      );

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<Either<Failure, String>> upsertDraftIncome({
    String? localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required String refMoneyType,
    required String refIncomeType,
    String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? refBankAccount,
  }) async {
    try {
      var resolvedRefParty = refParty?.trim();
      if (resolvedRefParty == null || resolvedRefParty.isEmpty) {
        resolvedRefParty = await _resolveLocalPartyIdByName(partyName);
      }

      final now = DateTime.now().toIso8601String();
      final incomeId = (localId != null && localId.trim().isNotEmpty)
          ? localId.trim()
          : '${docno}_${DateTime.now().millisecondsSinceEpoch}';
      final existing = await _localDataSource.getIncomeById(incomeId);
      final incomeSubHasRemark = await _incomeSubHasRemarkColumn();
      final incomeSubHasDetail = await _incomeSubHasDetailColumn();
      final moneyDomain = existing?.moneyDomain ??
          await _inferMoneyDomainForHeaderIncomeType(refIncomeType);
      final bankReferenceValue = bankReference == null
          ? existing?.bankReference
          : (bankReference.trim().isEmpty ? null : bankReference.trim());

      await _localDataSource.db.transaction((txn) async {
        await _localDataSource.saveIncome(
          IncomeModel(
            id: incomeId,
            docno: docno,
            docdate: docdate,
            amount: amount,
            detail: detail,
            remark: remark,
            bankReference: bankReferenceValue,
            created: existing?.created ?? now,
            refBudgetSource: refBudgetSource,
            refParty: resolvedRefParty,
            partyName: partyName,
            refMoneyType: refMoneyType,
            refBankAccount: refBankAccount?.trim().isNotEmpty == true
                ? refBankAccount!.trim()
                : existing?.refBankAccount,
            docStatus: 'draft',
            moneyDomain: moneyDomain,
            approvedBy: existing?.approvedBy,
            approvedAt: existing?.approvedAt,
            postedAt: existing?.postedAt,
            changeReason: existing?.changeReason,
          ),
          synced: false,
          executor: txn,
        );

        await txn.delete(
          'income_sub',
          where: 'refIncome = ?',
          whereArgs: [incomeId],
        );
        for (var i = 0; i < subData.length; i++) {
          final sub = subData[i];
          final subRow = <String, Object?>{
            'id': '${incomeId}_sub_$i',
            'refIncome': incomeId,
            'amount': sqliteMoneyToDouble(sub['amount']),
            'refIncomeType': sub['refincometype']?.toString(),
            'refMoneyType': sub['refmoneytype']?.toString() ??
                sub['refMoneyType']?.toString() ??
                refMoneyType,
            'synced': 0,
            'lastModified': now,
          };
          if (incomeSubHasRemark) {
            subRow['remark'] = sub['remark']?.toString() ?? '';
          }
          if (incomeSubHasDetail) {
            subRow['detail'] = sub['detail']?.toString() ?? '';
          }
          await txn.insert(
            'income_sub',
            subRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      });

      final resolvedRefBank =
          (refBankAccount ?? existing?.refBankAccount)?.trim() ?? '';
      await _syncService.addPendingRequest(
        id: 'income_upsert_$incomeId',
        method: int.tryParse(incomeId) != null ? 'PATCH' : 'POST',
        endpoint: int.tryParse(incomeId) != null
            ? '${baseurl}income/$incomeId'
            : '${baseurl}income',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          if (bankReference != null) 'bank_reference': bankReferenceValue ?? '',
          'partyname': partyName,
          if (resolvedRefParty != null && resolvedRefParty.isNotEmpty)
            'refparty': resolvedRefParty,
          'refuser': refUser,
          'refmoneytype': refMoneyType,
          'refincometype': refIncomeType,
          if (refBudgetSource != null && refBudgetSource.isNotEmpty)
            'refbudgetsource': refBudgetSource,
          if (resolvedRefBank.isNotEmpty) 'refbankaccount': resolvedRefBank,
          'subdata': jsonEncode(subData),
          'money_domain': moneyDomain,
          'doc_status': 'draft',
        }),
        silent: true,
      );

      return Right(incomeId);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  /// อัปเดตข้อมูล income ใน local แล้ว queue sync payload ล่าสุดขึ้น server
  Future<Either<Failure, void>> updateIncome({
    required String localId,
    required String token,
    required String docno,
    required String docdate,
    required String amount,
    required String detail,
    required String remark,
    String? bankReference,
    required String partyName,
    String? refParty,
    required String refUser,
    required String refMoneyType,
    required String refIncomeType,
    String? refBudgetSource,
    required List<Map<String, dynamic>> subData,
    String? changeReason,
    String? refBankAccount,
    String? receiptBookId,
    String? receiptNo,
    bool bumpBudgetSourceBudgetAmount = true,
    String? docStatus,
  }) async {
    try {
      final incomeSubHasRemark = await _incomeSubHasRemarkColumn();
      final existing = await _localDataSource.getIncomeById(localId);
      final moneyDomain = existing?.moneyDomain ??
          await _inferMoneyDomainForHeaderIncomeType(refIncomeType);
      final effectiveDocStatus = docStatus?.trim().isNotEmpty == true
          ? docStatus!.trim()
          : (existing?.docStatus ?? 'posted');
      final bankReferenceValue = bankReference == null
          ? existing?.bankReference
          : (bankReference.trim().isEmpty ? null : bankReference.trim());
      final wasDraft =
          (existing?.docStatus ?? '').trim().toLowerCase() == 'draft';
      final resolvedChangeReason =
          (changeReason != null && changeReason.trim().isNotEmpty)
              ? changeReason.trim()
              : existing?.changeReason;
      final amt = sqliteMoneyToDouble(amount);
      final bookIdTrim = receiptBookId?.trim();
      final receiptNoTrim = receiptNo?.trim() ?? '';
      final wantsReceipt = bookIdTrim != null &&
          bookIdTrim.isNotEmpty &&
          receiptNoTrim.isNotEmpty;

      if (wantsReceipt) {
        final receiptErr = await _validateReceiptForCreate(
          bookId: bookIdTrim,
          receiptNo: receiptNoTrim,
        );
        if (receiptErr != null) return Left(CacheFailure(message: receiptErr));
      }

      await _localDataSource.saveIncome(
        IncomeModel(
          id: localId,
          docno: docno,
          docdate: docdate,
          amount: amount,
          detail: detail,
          remark: remark,
          bankReference: bankReferenceValue,
          created: existing?.created ?? DateTime.now().toIso8601String(),
          refBudgetSource: refBudgetSource,
          refParty: refParty,
          partyName: partyName,
          refMoneyType: refMoneyType,
          refBankAccount: refBankAccount ?? existing?.refBankAccount,
          docStatus: effectiveDocStatus,
          moneyDomain: moneyDomain,
          approvedBy: existing?.approvedBy,
          approvedAt: existing?.approvedAt,
          postedAt: effectiveDocStatus == 'posted'
              ? (existing?.postedAt ?? DateTime.now().toIso8601String())
              : existing?.postedAt,
          changeReason: resolvedChangeReason,
        ),
        synced: false,
      );

      // Replace sub-items in local income_sub (delete old + insert new)
      await _localDataSource.db.delete(
        'income_sub',
        where: 'refIncome = ?',
        whereArgs: [localId],
      );
      final subBatch = _localDataSource.db.batch();
      for (var i = 0; i < subData.length; i++) {
        final sub = subData[i];
        final subRow = <String, Object?>{
          'id': '${localId}_sub_$i',
          'refIncome': localId,
          'amount': sqliteMoneyToDouble(sub['amount']),
          'refIncomeType': sub['refincometype']?.toString(),
          'refMoneyType': sub['refmoneytype']?.toString() ??
              sub['refMoneyType']?.toString() ??
              refMoneyType,
          'synced': 0,
          'lastModified': DateTime.now().toIso8601String(),
        };
        if (incomeSubHasRemark) {
          subRow['remark'] = sub['remark']?.toString() ?? '';
        }
        subBatch.insert(
          'income_sub',
          subRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await subBatch.commit(noResult: true);

      if (wasDraft &&
          effectiveDocStatus != 'draft' &&
          bumpBudgetSourceBudgetAmount &&
          refBudgetSource != null &&
          refBudgetSource.trim().isNotEmpty &&
          amt > 0) {
        await _localDataSource.db.rawUpdate(
          '''
          UPDATE budget_source_budget
          SET budget_amount = budget_amount + ?,
              lastModified = ?
          WHERE id = ?
          ''',
          [amt, DateTime.now().toIso8601String(), refBudgetSource],
        );
      }

      if (wantsReceipt) {
        final nowIso = DateTime.now().toIso8601String();
        final issueId =
            'ri_${localId}_${DateTime.now().microsecondsSinceEpoch}';
        await _localDataSource.db.insert(
          'receipt_issue',
          {
            'id': issueId,
            'ref_book': bookIdTrim,
            'receipt_no': receiptNoTrim,
            'issued_at': nowIso,
            'issued_to': partyName,
            'amount': amt,
            'issue_status': 'used',
            'remark': docno,
            'ref_income': localId,
            'created': nowIso,
            'synced': 0,
            'last_modified': nowIso,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      final useServerPatch = int.tryParse(localId) != null;
      final resolvedRefBank =
          (refBankAccount ?? existing?.refBankAccount)?.trim() ?? '';
      await _syncService.addPendingRequest(
        id: 'income_upsert_$localId',
        method: useServerPatch ? 'PATCH' : 'POST',
        endpoint:
            useServerPatch ? '${baseurl}income/$localId' : '${baseurl}income',
        payload: jsonEncode({
          'token': token,
          'docno': docno,
          'docdate': docdate,
          'amount': amount,
          'detail': detail,
          'remark': remark,
          if (bankReference != null) 'bank_reference': bankReferenceValue ?? '',
          'partyname': partyName,
          if (refParty != null && refParty.isNotEmpty) 'refparty': refParty,
          'refuser': refUser,
          'refmoneytype': refMoneyType,
          'refincometype': refIncomeType,
          if (refBudgetSource != null && refBudgetSource.isNotEmpty)
            'refbudgetsource': refBudgetSource,
          if (resolvedRefBank.isNotEmpty) 'refbankaccount': resolvedRefBank,
          'subdata': jsonEncode(subData),
          'money_domain': moneyDomain,
          'doc_status': effectiveDocStatus,
          if (resolvedChangeReason != null && resolvedChangeReason.isNotEmpty)
            'change_reason': resolvedChangeReason,
        }),
      );

      await _auditLogLocalDataSource?.logEvent(
        module: 'income',
        action: 'update',
        entityId: localId,
        payload: {
          'docno': docno,
          'amount': amount,
        },
      );

      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  Future<String?> _resolveLocalPartyIdByName(String partyName) async {
    final n = partyName.trim();
    if (n.isEmpty) return null;
    final rows = await _localDataSource.db.query(
      'party',
      columns: ['id'],
      where: 'LOWER(TRIM(name)) = ? AND (LOWER(TRIM(role)) IN (?,?,?))',
      whereArgs: [n.toLowerCase(), 'payer', 'both', 'payee'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['id']?.toString();
  }

  Future<String?> _validateReceiptForCreate({
    required String bookId,
    required String receiptNo,
  }) async {
    final books = await _localDataSource.db.query(
      'receipt_book',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (books.isEmpty) return 'ไม่พบเล่มใบเสร็จที่เลือก';
    final b = books.first;
    final startRaw = b['start_no']?.toString().trim() ?? '';
    final endRaw = b['end_no']?.toString().trim() ?? '';
    final nReceipt = int.tryParse(receiptNo.replaceAll(RegExp(r'[^0-9]'), ''));
    final nStart = int.tryParse(startRaw.replaceAll(RegExp(r'[^0-9]'), ''));
    final nEnd = int.tryParse(endRaw.replaceAll(RegExp(r'[^0-9]'), ''));
    if (nReceipt == null || nStart == null || nEnd == null) {
      return 'รูปแบบเลขที่ใบเสร็จไม่ถูกต้อง';
    }
    if (nReceipt < nStart || nReceipt > nEnd) {
      return 'เลขที่ใบเสร็จต้องอยู่ในช่วงที่กำหนดในเล่ม';
    }
    final dup = await _localDataSource.db.query(
      'receipt_issue',
      columns: ['id'],
      where: 'ref_book = ? AND receipt_no = ?',
      whereArgs: [bookId, receiptNo],
      limit: 1,
    );
    if (dup.isNotEmpty) return 'เลขที่ใบเสร็จนี้ถูกใช้แล้วในเล่มเดียวกัน';

    final issues = await _localDataSource.db.query(
      'receipt_issue',
      columns: ['receipt_no'],
      where: 'ref_book = ?',
      whereArgs: [bookId],
    );
    var maxIssued = 0;
    for (final row in issues) {
      final n = int.tryParse(
        (row['receipt_no'] ?? '').toString().replaceAll(RegExp(r'[^0-9]'), ''),
      );
      if (n != null && n > maxIssued) maxIssued = n;
    }
    final expected = maxIssued == 0 ? nStart : maxIssued + 1;
    if (nReceipt != expected) {
      final display = IncomeLocalDataSource.formatReceiptNoLikePattern(
        pattern: startRaw,
        value: expected,
      );
      return TransactionUiText.incomeReceiptNoMustBeSequentialNext(display);
    }
    return null;
  }

  Future<bool> _incomeSubHasRemarkColumn() async {
    final columns = await _localDataSource.db.rawQuery(
      "PRAGMA table_info('income_sub')",
    );
    for (final column in columns) {
      if ((column['name']?.toString() ?? '').toLowerCase() == 'remark') {
        return true;
      }
    }
    return false;
  }

  Future<bool> _incomeSubHasDetailColumn() async {
    final columns = await _localDataSource.db.rawQuery(
      "PRAGMA table_info('income_sub')",
    );
    for (final column in columns) {
      if ((column['name']?.toString() ?? '').toLowerCase() == 'detail') {
        return true;
      }
    }
    return false;
  }

  @override
  Future<Either<Failure, void>> deleteIncomeOfflineFirst({
    required String localId,
    required String token,
  }) async {
    try {
      final existing = await _localDataSource.getIncomeById(localId);
      await _syncService.cancelPendingRequest('income_create_$localId');
      await _syncService.cancelPendingRequest('income_upsert_$localId');
      await _localDataSource.deleteIncome(localId);
      if (existing?.synced ?? false) {
        await _syncService.addPendingRequest(
          id: 'income_delete_$localId',
          method: 'DELETE',
          endpoint: '${baseurl}income/$localId',
          payload: jsonEncode({
            'token': token,
            'docno': existing?.docno,
          }),
        );
      }
      await _auditLogLocalDataSource?.logEvent(
        module: 'income',
        action: 'delete',
        entityId: localId,
        payload: {
          'id': localId,
        },
      );
      return const Right(null);
    } catch (e) {
      return Left(CacheFailure(message: e.toString()));
    }
  }

  // ─── BACKGROUND PULL: อัปเดต local cache จาก server ──────────────────────

  /// ดึง income list ใหม่จาก server แล้วบันทึก local
  /// เรียกแบบ fire-and-forget จาก Provider — ไม่ throw exception
  static const int _backupListPageSizeHint = 100;
  static const int _backupMaxPages = 400;

  /// ดึงรายรับทุกหน้าจากเซิร์ฟเวอร์แล้วเขียนลง local (ใช้ก่อนเทียบ digest)
  Future<void> pullAllIncomePagesForBackup() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    final merged = <IncomeModel>[];
    for (var page = 1; page <= _backupMaxPages; page++) {
      List<IncomeEntity> chunk;
      try {
        chunk = await _remoteDataSource.getIncomeList(page: page);
      } catch (_) {
        break;
      }
      if (chunk.isEmpty) break;
      merged.addAll(
        chunk.map(
          (e) => IncomeModel(
            id: e.id,
            docno: e.docno,
            docdate: e.docdate,
            detail: e.detail,
            amount: e.amount,
            remark: e.remark,
            bankReference: e.bankReference,
            created: e.created,
            refBudgetSource: e.refBudgetSource,
            refParty: e.refParty,
            partyName: e.partyName,
            refMoneyType: e.refMoneyType,
            docStatus: e.docStatus,
            moneyDomain: e.moneyDomain,
            approvedBy: e.approvedBy,
            approvedAt: e.approvedAt,
            postedAt: e.postedAt,
            changeReason: e.changeReason,
          ),
        ),
      );
      if (chunk.length < _backupListPageSizeHint) break;
    }
    if (merged.isNotEmpty) {
      await _localDataSource.saveIncomes(merged);
      debugPrint(
        'IncomeRepository: backup pull merged ${merged.length} income rows',
      );
    }
  }

  /// ดึงแหล่งงบจาก API แล้วอัปเดต local (ใช้ก่อนเทียบ digest)
  Future<void> pullBudgetSourcesFromRemoteForBackup() async {
    await _backgroundPullBudgetSourcesFromRemote();
  }

  Future<void> backgroundPull() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final remote = await _remoteDataSource.getIncomeList();
      await _localDataSource.saveIncomes(remote
          .map((e) => IncomeModel(
                id: e.id,
                docno: e.docno,
                docdate: e.docdate,
                detail: e.detail,
                amount: e.amount,
                remark: e.remark,
                bankReference: e.bankReference,
                created: e.created,
                refBudgetSource: e.refBudgetSource,
                refParty: e.refParty,
                partyName: e.partyName,
                refMoneyType: e.refMoneyType,
                docStatus: e.docStatus,
                moneyDomain: e.moneyDomain,
                approvedBy: e.approvedBy,
                approvedAt: e.approvedAt,
                postedAt: e.postedAt,
                changeReason: e.changeReason,
              ))
          .toList());
      debugPrint(
          'IncomeRepository: background pull success (${remote.length} items)');
    } catch (e) {
      debugPrint('IncomeRepository: background pull failed: $e');
    }
  }

  /// ดึง lookup tables (moneyType, incomeType) จาก server แล้ว cache local
  Future<void> backgroundPullLookups() async {
    if (!await LicenseMode.canSyncOnline() || !await _networkInfo.isConnected) {
      return;
    }
    try {
      final moneyTypes = await _remoteDataSource.getMoneyTypes();
      final incomeTypes = await _remoteDataSource.getIncomeTypes();

      final db = _localDataSource.db;
      final batch = db.batch();

      for (final t in moneyTypes) {
        batch.insert(
          'money_type',
          {
            'id': t.id,
            'code': t.id,
            'name': t.name,
            'detail': '',
            'synced': 1,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      for (final t in incomeTypes) {
        batch.insert(
          'income_type',
          {
            'id': t.id,
            'code': t.id,
            'name': t.name,
            'detail': '',
            'synced': 1,
            'lastModified': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      debugPrint('IncomeRepository: lookup pull success');
    } catch (e) {
      debugPrint('IncomeRepository: lookup pull failed: $e');
    }

    try {
      final parties = await _remoteDataSource.fetchPartiesAllPages(
        activeOnly: false,
      );
      await _persistPartyRowsFromApi(parties);
      debugPrint(
          'IncomeRepository: party master pull success (${parties.length} rows)');
    } catch (e) {
      debugPrint('IncomeRepository: party master pull failed: $e');
    }
  }

  String _serverPartyIdFromBody(Map<String, dynamic> raw) {
    for (final k in ['lastid', 'lastId', 'id']) {
      final v = raw[k];
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return '';
  }

  @override
  Future<String> createPartyOfflineFirst({
    required String token,
    int? actorId,
    String? actorName,
    required String name,
    required String role,
    String phone = '',
    String taxid = '',
    String remark = '',
  }) async {
    final localId = 'lp_${DateTime.now().microsecondsSinceEpoch}';
    final dupCreate = await _localDataSource.findPartyRowWithConflictingTaxId(
        taxIdRaw: taxid);
    if (dupCreate != null) {
      throw PartyTaxIdDuplicateException(dupCreate['name']?.toString() ?? '');
    }
    await _localDataSource.upsertPartyRow(
      id: localId,
      name: name.trim(),
      role: role.toLowerCase(),
      phone: phone.trim().isEmpty ? null : phone.trim(),
      taxid: taxid.trim().isEmpty ? null : taxid.trim(),
      remark: remark.trim().isEmpty ? null : remark.trim(),
      isActive: true,
      synced: 0,
    );
    await _syncService.addPendingRequest(
      id: 'party_create_$localId',
      method: 'POST',
      endpoint: '${baseurl}party',
      payload: jsonEncode({
        'token': token,
        'actor_id': actorId,
        'actor_name': actorName,
        'name': name.trim(),
        'role': role.toLowerCase(),
        'phone': phone.trim(),
        'taxid': taxid.trim(),
        'remark': remark.trim(),
      }),
    );
    return localId;
  }

  @override
  Future<void> updatePartyOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
    required String name,
    required String role,
    String phone = '',
    String taxid = '',
    String remark = '',
  }) async {
    final row = await _localDataSource.getPartyRow(partyId);
    if (row == null) return;
    final dupUpdate = await _localDataSource.findPartyRowWithConflictingTaxId(
      taxIdRaw: taxid,
      excludePartyId: partyId,
    );
    if (dupUpdate != null) {
      throw PartyTaxIdDuplicateException(dupUpdate['name']?.toString() ?? '');
    }
    final isActive = row['isactive'] == 1 ||
        row['isactive'] == true ||
        row['isactive']?.toString() == '1';
    await _localDataSource.upsertPartyRow(
      id: partyId,
      name: name.trim(),
      role: role.toLowerCase(),
      phone: phone.trim().isEmpty ? null : phone.trim(),
      taxid: taxid.trim().isEmpty ? null : taxid.trim(),
      remark: remark.trim().isEmpty ? null : remark.trim(),
      isActive: isActive,
      synced: 0,
    );
    final payload = jsonEncode({
      'token': token,
      'actor_id': actorId,
      'actor_name': actorName,
      'name': name.trim(),
      'role': role.toLowerCase(),
      'phone': phone.trim(),
      'taxid': taxid.trim(),
      'remark': remark.trim(),
    });
    if (partyId.startsWith('lp_')) {
      await _syncService.addPendingRequest(
        id: 'party_create_$partyId',
        method: 'POST',
        endpoint: '${baseurl}party',
        payload: payload,
      );
    } else {
      await _syncService.addPendingRequest(
        id: 'party_patch:$partyId',
        method: 'PATCH',
        endpoint: '${baseurl}party/$partyId',
        payload: payload,
      );
    }
  }

  @override
  Future<void> setPartyActiveOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
    required bool isActive,
  }) async {
    final row = await _localDataSource.getPartyRow(partyId);
    if (row == null) return;
    await _localDataSource.upsertPartyRow(
      id: partyId,
      name: (row['name'] ?? '').toString(),
      role: (row['role'] ?? 'both').toString().toLowerCase(),
      phone: row['phone']?.toString(),
      taxid: row['taxid']?.toString(),
      remark: row['remark']?.toString(),
      isActive: isActive,
      synced: 0,
    );
    if (partyId.startsWith('lp_')) {
      await _syncService.addPendingRequest(
        id: 'party_create_$partyId',
        method: 'POST',
        endpoint: '${baseurl}party',
        payload: jsonEncode({
          'token': token,
          'actor_id': actorId,
          'actor_name': actorName,
          'name': (row['name'] ?? '').toString(),
          'role': (row['role'] ?? 'both').toString().toLowerCase(),
          'phone': row['phone']?.toString() ?? '',
          'taxid': row['taxid']?.toString() ?? '',
          'remark': row['remark']?.toString() ?? '',
        }),
      );
      return;
    }
    await _syncService.addPendingRequest(
      id: 'party_patch:$partyId',
      method: 'PATCH',
      endpoint: '${baseurl}party/$partyId',
      payload: jsonEncode({
        'token': token,
        'actor_id': actorId,
        'actor_name': actorName,
        'isactive': isActive,
      }),
    );
  }

  @override
  Future<void> deletePartyOfflineFirst({
    required String partyId,
    required String token,
    int? actorId,
    String? actorName,
  }) async {
    final row = await _localDataSource.getPartyRow(partyId);
    if (row == null) return;

    await _syncService.cancelPendingPartyWrites(partyId);
    await _localDataSource.deletePartyById(partyId);

    if (partyId.startsWith('lp_')) {
      return;
    }
    await _syncService.addPendingRequest(
      id: 'party_delete:$partyId',
      method: 'DELETE',
      endpoint: '${baseurl}party/$partyId',
      payload: jsonEncode({
        'token': token,
        'actor_id': actorId,
        'actor_name': actorName,
      }),
    );
  }

  /// เรียกจาก [SyncService] หลัง POST `/party` สำเร็จ — แม็ป `lp_...` → id เซิร์ฟเวอร์
  Future<void> applyPartyCreateSyncSuccess(
    String localPartyId,
    Map<String, dynamic> responseBody, {
    String? queueToken,
  }) async {
    final serverId = _serverPartyIdFromBody(responseBody);
    if (serverId.isEmpty) return;
    final row = await _localDataSource.getPartyRow(localPartyId);
    if (row == null) return;
    final wasInactive = !(row['isactive'] == 1 ||
        row['isactive'] == true ||
        row['isactive']?.toString() == '1');
    await _localDataSource.replacePartyPrimaryKey(localPartyId, serverId);
    final tok = (queueToken ?? '').trim();
    if (wasInactive && tok.isNotEmpty) {
      await _syncService.addPendingRequest(
        id: 'party_patch:$serverId:inactive',
        method: 'PATCH',
        endpoint: '${baseurl}party/$serverId',
        payload: jsonEncode({
          'token': tok,
          'isactive': false,
        }),
      );
    }
  }

  /// เรียกจาก [SyncService] หลัง PATCH `/party/:id` จากคิวสำเร็จ
  Future<void> applyPartyPatchSyncSuccess(String serverPartyId) async {
    await _localDataSource.markPartySynced(serverPartyId);
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  Future<void> clearLocalCache() => _localDataSource.clearAllIncomes();

  Future<bool> get isConnected => _networkInfo.isConnected;

  Stream<bool> get onConnectivityChanged => _networkInfo.onConnectivityChanged;
}
