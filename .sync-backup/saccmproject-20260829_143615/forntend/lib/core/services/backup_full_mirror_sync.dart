import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:saccm/config.dart';
import 'package:saccm/constants/transaction_ui_text.dart';
import 'package:sqflite/sqflite.dart';

/// ดึงข้อมูลจาก REST แบบหลายหน้าแล้วเขียนลง SQLite ให้ตรงกับเซิร์ฟเวอร์ (ใช้ก่อนเทียบ digest ตอนสำรอง)
///
/// ลบแถวในตารางที่ mirror แล้วใส่ใหม่จาก API — ต้องเรียกเมื่อคิว [pending_requests] ว่างแล้วเท่านั้น
class BackupFullMirrorSync {
  BackupFullMirrorSync._();

  static const int _pageHint = 100;
  static const int _maxPages = 500;
  static const Map<String, String> _protectedLocalTables = {
    'income': 'รายรับ',
    'income_sub': 'แถวรายรับ',
    'expense': 'รายจ่าย',
    'expense_sub': 'แถวรายจ่าย',
    'expense_req': 'ใบขอเบิก',
    'expense_req_sub': 'แถวใบขอเบิก',
    'loan': 'สัญญายืมเงิน',
    'loan_sub': 'แถวสัญญายืมเงิน',
    'repay_loan': 'ชำระคืนเงินยืม',
    'repay_loan_sub': 'แถวชำระคืนเงินยืม',
    'pay_cheque': 'จ่ายเช็ค',
    'bank_account': 'บัญชีธนาคาร',
    'cheque_account': 'บัญชีเช็ค',
    'member': 'สมาชิก',
    'users': 'ผู้ใช้',
    'budget_source_master': 'แหล่งเงิน',
    'budget_source_budget': 'วงเงินแหล่งเงิน',
    'party': 'คู่ค้า/ผู้เกี่ยวข้อง',
    'deposit_guarantee': 'เงินประกัน/ภาษีหัก',
  };

  static String _u(String relativePath) {
    final b = baseurl;
    return b.endsWith('/') ? '$b$relativePath' : '$b/$relativePath';
  }

  static String _pageUrl(String relativePath, int page) {
    if (page <= 1) return _u(relativePath);
    final sep = relativePath.contains('?') ? '&' : '?';
    return '${_u(relativePath)}${sep}page=$page';
  }

  static Map<String, dynamic> _norm(Map<dynamic, dynamic> raw) {
    return {
      for (final e in raw.entries) e.key.toString().toLowerCase(): e.value,
    };
  }

  static String _s(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return '';
    return v.toString();
  }

  static String _ts(dynamic v) {
    if (v == null) return '';
    if (v is String) return v;
    return v.toString();
  }

  static double _money(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim()) ?? 0;
  }

  static int _boolInt(Map<String, dynamic> m, String a, String b) {
    final v = m[a] ?? m[b];
    if (v is int) return v;
    if (v is bool) return v ? 1 : 0;
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }

  static Future<List<Map<String, dynamic>>> _pullAllPages(
    Dio dio,
    String relativePath,
  ) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= _maxPages; page++) {
      try {
        final resp = await dio.get<dynamic>(
          _pageUrl(relativePath, page),
          options: Options(
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 15),
          ),
        );
        if (resp.statusCode != 200) break;
        final body = resp.data;
        if (body is! Map) break;
        final data = body['data'];
        if (data is! List || data.isEmpty) break;
        for (final e in data) {
          if (e is Map) {
            out.add(_norm(Map<dynamic, dynamic>.from(e)));
          }
        }
        if (data.length < _pageHint) break;
      } catch (e) {
        debugPrint('BackupFullMirrorSync: $relativePath page $page: $e');
        break;
      }
    }
    return out;
  }

  /// ลบแถวใน [table] ที่ id ไม่อยู่ใน [keepIds] — ให้จำนวนแถวตรงกับเซิร์ฟเวอร์หลัง mirror
  ///
  /// ถ้า [keepIds] ว่างจะไม่ลบทั้งตาราง (กันดึงล้มเหลวแล้วเผลอลบข้อมูล master ในเครื่อง)
  static Future<void> _pruneRowsNotInServerIds(
    Transaction txn,
    String table,
    String idColumn,
    Set<String> keepIds,
  ) async {
    if (keepIds.isEmpty) {
      return;
    }
    final args = keepIds.toList();
    final ph = List.filled(args.length, '?').join(',');
    await txn.rawDelete(
      'DELETE FROM $table WHERE $idColumn NOT IN ($ph)',
      args,
    );
  }

  static Future<void> _assertNoUnsafeLocalState(Database db) async {
    final pendingCount = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM pending_requests'),
        ) ??
        0;
    if (pendingCount > 0) {
      throw StateError(
        TransactionUiText.backupPendingQueueNotEmpty(pendingCount),
      );
    }

    final blocked = <String>[];
    for (final entry in _protectedLocalTables.entries) {
      final count = Sqflite.firstIntValue(
            await db.rawQuery(
              'SELECT COUNT(*) FROM ${entry.key} WHERE synced = 0',
            ),
          ) ??
          0;
      if (count > 0) {
        blocked.add('${entry.value} $count');
      }
    }

    if (blocked.isNotEmpty) {
      throw StateError(
        TransactionUiText.backupUnsyncedLocalRows(blocked.join(', ')),
      );
    }
  }

  /// ดึงเฉพาะ master/lookup (ไม่ลบรายการรับ-จ่าย) — ใช้หลังเปิดใช้งาน license
  static Future<void> runMastersOnly({
    required Dio dio,
    required Database db,
  }) async {
    await db.transaction((txn) async {
      await _insertMasters(txn, dio);
      await _insertBudget(txn, dio);
    });
    debugPrint('BackupFullMirrorSync: runMastersOnly completed');
  }

  static Future<void> run({
    required Dio dio,
    required Database db,
  }) async {
    await _assertNoUnsafeLocalState(db);
    await db.transaction((txn) async {
      await _deleteMirrorData(txn);
      await _insertMasters(txn, dio);
      await _insertBudget(txn, dio);
      await _insertMembersAndUsers(txn, dio);
      await _insertIncomeBlock(txn, dio);
      await _insertExpenseReqBlock(txn, dio);
      await _insertExpenseBlock(txn, dio);
      await _insertLoanBlock(txn, dio);
      await _insertRepayBlock(txn, dio);
      await _insertBankAccounts(txn, dio);
      await _insertPayCheques(txn, dio);
      await _insertPartyAllPages(txn, dio);
      await _insertDepositGuarantee(txn, dio);
      await _applyLocalDeleteTombstones(txn);
    });
  }

  static Future<void> _applyLocalDeleteTombstones(Transaction txn) async {
    const tableByModule = {
      'income': ('income', true),
      'expense': ('expense', true),
      'expense_req': ('expense_req', true),
      'loan': ('loan', true),
      'repay_loan': ('repay_loan', true),
      'party': ('party', false),
      'member': ('member', false),
    };

    for (final entry in tableByModule.entries) {
      final logs = await txn.query(
        'audit_log',
        columns: ['entityId', 'payload'],
        where: 'module = ? AND action = ?',
        whereArgs: [entry.key, 'delete'],
      );
      for (final log in logs) {
        final ids = <String>{};
        final docnos = <String>{};
        final entityId = log['entityId']?.toString().trim() ?? '';
        if (entityId.isNotEmpty) {
          ids.add(entityId);
        }

        final payload = log['payload']?.toString() ?? '';
        if (payload.isNotEmpty) {
          try {
            final decoded = jsonDecode(payload);
            if (decoded is Map) {
              final id =
                  decoded['_localId'] ?? decoded['id'] ?? decoded['server_id'];
              final docno = decoded['docno'] ?? decoded['docNo'];
              if (id != null && id.toString().trim().isNotEmpty) {
                ids.add(id.toString().trim());
              }
              if (docno != null && docno.toString().trim().isNotEmpty) {
                docnos.add(docno.toString().trim());
              }
            }
          } catch (_) {
            // Ignore malformed historical audit payloads.
          }
        }

        final table = entry.value.$1;
        final hasDocno = entry.value.$2;
        for (final id in ids) {
          await txn.delete(table, where: 'id = ?', whereArgs: [id]);
        }
        if (hasDocno) {
          for (final docno in docnos) {
            await txn.delete(table, where: 'docno = ?', whereArgs: [docno]);
          }
        }
      }
    }
  }

  static Future<void> _deleteMirrorData(Transaction txn) async {
    await txn.execute('DELETE FROM pay_cheque');
    await txn.execute('DELETE FROM repay_loan_sub');
    await txn.execute('DELETE FROM repay_loan');
    await txn.execute('DELETE FROM loan_sub');
    await txn.execute('DELETE FROM loan');
    await txn.execute('DELETE FROM expense_sub');
    await txn.execute('DELETE FROM expense');
    await txn.execute('DELETE FROM income_sub');
    await txn.execute('DELETE FROM income');
    await txn.execute('DELETE FROM expense_req_sub');
    await txn.execute('DELETE FROM expense_req');
    await txn.execute('DELETE FROM bank_account');
    await txn.execute('DELETE FROM cheque_account');
    await txn.execute('DELETE FROM member');
    await txn.execute('DELETE FROM users');
    await txn.execute('DELETE FROM budget_source_budget');
    await txn.execute('DELETE FROM budget_source_master');
    await txn.execute('DELETE FROM party');
    await txn.execute('DELETE FROM deposit_guarantee');
    // ไม่ลบ bank / usergroup / prefix / doc_group / money_group / money_type / income_type /
    // usergroup_permission — อัปเดตแบบ INSERT OR REPLACE ใน _insertMasters เพื่อไม่ให้สิทธิ์หาย
  }

  static Future<void> _insertMasters(Transaction txn, Dio dio) async {
    final banks = await _pullAllPages(dio, 'bank');
    final bankIds = <String>{};
    for (final r in banks) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      bankIds.add(id);
      await txn.insert(
        'bank',
        {
          'id': id,
          'name': _s(r, 'name'),
          'shortname': _s(r, 'shortname'),
          'code': _s(r, 'code'),
          'sort': int.tryParse(_s(r, 'sort')) ?? 0,
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'bank', 'id', bankIds);

    final groups = await _pullAllPages(dio, 'usersgroup');
    final usergroupIds = <String>{};
    for (final r in groups) {
      final gid = int.tryParse(_s(r, 'id'));
      if (gid == null || gid <= 0) continue;
      usergroupIds.add(gid.toString());
      await txn.insert(
        'usergroup',
        {
          'id': gid,
          'nameth': _s(r, 'nameth'),
          'nameen': _s(r, 'nameen'),
          'use': 'Y',
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'usergroup', 'id', usergroupIds);

    final prefixes = await _pullAllPages(dio, 'prefix');
    final prefixIds = <String>{};
    for (final r in prefixes) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      prefixIds.add(id);
      await txn.insert(
        'prefix',
        {
          'id': id,
          'prefixTh': _s(r, 'prefixth'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'prefix', 'id', prefixIds);

    final docgroups = await _pullAllPages(dio, 'docgroup');
    final docIds = <String>{};
    for (final r in docgroups) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      docIds.add(id);
      await txn.insert(
        'doc_group',
        {
          'id': id,
          'tablename': _s(r, 'tablename'),
          'name': _s(r, 'name'),
          'rungroup': _s(r, 'rungroup'),
          'docnoformat': _s(r, 'docnoformat'),
          'runtaxgroup': _s(r, 'runtaxgroup'),
          'taxnoformat': _s(r, 'taxnoformat'),
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'doc_group', 'id', docIds);

    final mgs = await _pullAllPages(dio, 'moneygroup');
    final moneyGroupIds = <String>{};
    for (final r in mgs) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      moneyGroupIds.add(id);
      await txn.insert(
        'money_group',
        {
          'id': id,
          'name': _s(r, 'name'),
          'remark': _s(r, 'remark'),
          'sort': int.tryParse(_s(r, 'sort')) ?? 0,
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'money_group', 'id', moneyGroupIds);

    final mts = await _pullAllPages(dio, 'moneytype');
    final moneyTypeIds = <String>{};
    for (final r in mts) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      moneyTypeIds.add(id);
      await txn.insert(
        'money_type',
        {
          'id': id,
          'code': _s(r, 'code'),
          'name': _s(r, 'name'),
          'detail': _s(r, 'detail'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'money_type', 'id', moneyTypeIds);

    final its = await _pullAllPages(dio, 'incometype');
    final incomeTypeIds = <String>{};
    for (final r in its) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      incomeTypeIds.add(id);
      await txn.insert(
        'income_type',
        {
          'id': id,
          'code': _s(r, 'code'),
          'name': _s(r, 'name'),
          'detail': _s(r, 'detail'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'income_type', 'id', incomeTypeIds);

    final ets = await _pullAllPages(dio, 'expensetype');
    final expenseTypeIds = <String>{};
    for (final r in ets) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      expenseTypeIds.add(id);
      await txn.insert(
        'expense_type',
        {
          'id': id,
          'code': _s(r, 'code'),
          'name': _s(r, 'name'),
          'remark': _s(r, 'remark'),
          'sort': int.tryParse(_s(r, 'sort')) ?? 0,
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          if (_s(r, 'refdefaultbudgetsource').isNotEmpty)
            'refDefaultBudgetSource': _s(r, 'refdefaultbudgetsource'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'expense_type', 'id', expenseTypeIds);
  }

  static Future<void> _insertBudget(Transaction txn, Dio dio) async {
    final resp = await dio.get<dynamic>(
      _u('budgetsource'),
      queryParameters: const <String, dynamic>{'fullSync': '1'},
      options: Options(
        receiveTimeout: const Duration(seconds: 45),
        sendTimeout: const Duration(seconds: 15),
      ),
    );
    if (resp.statusCode != 200 || resp.data is! Map) return;
    final data = (resp.data as Map)['data'] as List? ?? [];
    final now = DateTime.now().toIso8601String();
    for (final e in data) {
      if (e is! Map) continue;
      final m = _norm(Map<dynamic, dynamic>.from(e));
      final id = _s(m, 'id');
      if (id.isEmpty) continue;
      final refIt = _s(m, 'ref_income_type').isNotEmpty
          ? _s(m, 'ref_income_type')
          : _s(m, 'refincometype');
      final rawList =
          m['ref_income_types'] ?? m['refincometypes'] ?? m['refIncomeTypes'];
      final linkedFundCategories = <String>{};
      if (rawList is List) {
        for (final v in rawList) {
          final s = (v ?? '').toString().trim();
          if (s.isNotEmpty) linkedFundCategories.add(s);
        }
      }
      if (linkedFundCategories.isEmpty && refIt.isNotEmpty) {
        linkedFundCategories.add(refIt);
      }
      final refMg = _s(m, 'ref_money_group').isNotEmpty
          ? _s(m, 'ref_money_group')
          : _s(m, 'refmoneygroup');
      final budgetType =
          _s(m, 'budget_type').isNotEmpty ? _s(m, 'budget_type') : 'unknown';
      double numField(String a, String b) {
        final v = m[a] ?? m[b];
        if (v is num) return v.toDouble();
        return double.tryParse(v?.toString() ?? '') ?? 0.0;
      }

      await txn.insert(
        'budget_source_master',
        {
          'id': id,
          'code': _s(m, 'code').isEmpty ? id : _s(m, 'code'),
          'name': _s(m, 'name'),
          'budget_type': budgetType,
          'refFundCategory': refIt.isEmpty ? null : refIt,
          'refmoneygroup': refMg.isEmpty ? null : refMg,
          'refBankAccount': () {
            final s = _s(m, 'refbankaccount');
            return s.isEmpty ? null : s;
          }(),
          'description': _s(m, 'description'),
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      for (final linkedFundCategory in linkedFundCategories) {
        await txn.insert(
          'income_type_budget_source_map',
          {
            'id': 'itbsm_${linkedFundCategory}_$id',
            'refIncomeType': linkedFundCategory,
            'refBudgetSourceMaster': id,
            'synced': 1,
            'lastModified': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      await txn.insert(
        'budget_source_budget',
        {
          'id': id,
          'refBudgetSourceMaster': id,
          'fiscal_year': _s(m, 'fiscal_year').isNotEmpty
              ? _s(m, 'fiscal_year')
              : DateTime.now().year.toString(),
          'budget_amount': numField('budget_amount', 'budgetamount'),
          'brought_forward_amount':
              numField('brought_forward_amount', 'broughtforwardamount'),
          'used_amount': numField('used_amount', 'usedamount'),
          'reserved_amount': numField('reserved_amount', 'reservedamount'),
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertMembersAndUsers(Transaction txn, Dio dio) async {
    final members = await _pullAllPages(dio, 'member');
    for (final r in members) {
      final name = _s(r, 'name');
      final ln = _s(r, 'lastname');
      await txn.insert(
        'member',
        {
          'id': _s(r, 'id'),
          'code': _s(r, 'code'),
          'name': ln.isNotEmpty ? '$name $ln'.trim() : name,
          'email': _s(r, 'email'),
          'phone': _s(r, 'contactnumber'),
          'address': _s(r, 'address'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final users = await _pullAllPages(dio, 'users');
    for (final r in users) {
      final uid = int.tryParse(_s(r, 'id'));
      if (uid == null || uid <= 0) continue;
      await txn.insert(
        'users',
        {
          'id': uid,
          'code': _s(r, 'code'),
          'email': _s(r, 'email'),
          'username': _s(r, 'username'),
          'password': _s(r, 'password'),
          'name': _s(r, 'name'),
          'lastname': _s(r, 'lastname'),
          'contactnumber': _s(r, 'contactnumber'),
          'refusergroup': int.tryParse(_s(r, 'refusergroup')),
          'refprefix': () {
            final s = _s(r, 'refprefix');
            return s.isEmpty ? null : s;
          }(),
          'forcePasswordChange':
              int.tryParse(_s(r, 'forcepasswordchange')) ?? 0,
          'isActive': int.tryParse(_s(r, 'isactive')) ?? 1,
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertIncomeBlock(Transaction txn, Dio dio) async {
    final incomes = await _pullAllPages(dio, 'income');
    for (final r in incomes) {
      await txn.insert(
        'income',
        {
          'id': _s(r, 'id'),
          'server_id': _s(r, 'id'),
          'docno': _s(r, 'docno'),
          'docdate': _ts(r['docdate']),
          'detail': _s(r, 'detail'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'bank_reference':
              _s(r, 'bank_reference').isEmpty ? null : _s(r, 'bank_reference'),
          'created': _ts(r['created']),
          'refBudgetSource': _s(r, 'refbudgetsource').isEmpty
              ? null
              : _s(r, 'refbudgetsource'),
          'refParty': _s(r, 'refparty').isEmpty ? null : _s(r, 'refparty'),
          'partyName': _s(r, 'party_name').isEmpty
              ? _s(r, 'partyname')
              : _s(r, 'party_name'),
          'refBankAccount':
              _s(r, 'refbankaccount').isEmpty ? null : _s(r, 'refbankaccount'),
          'refMoneyType':
              _s(r, 'refmoneytype').isEmpty ? null : _s(r, 'refmoneytype'),
          'doc_status':
              _s(r, 'doc_status').isEmpty ? 'posted' : _s(r, 'doc_status'),
          'money_domain':
              _s(r, 'money_domain').isEmpty ? null : _s(r, 'money_domain'),
          'approved_by':
              _s(r, 'approved_by').isEmpty ? null : _s(r, 'approved_by'),
          'approved_at': _ts(r['approved_at']),
          'posted_at': _ts(r['posted_at']),
          'change_reason':
              _s(r, 'change_reason').isEmpty ? null : _s(r, 'change_reason'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final subs = await _pullAllPages(dio, 'income/sub/');
    for (final r in subs) {
      await txn.insert(
        'income_sub',
        {
          'id': _s(r, 'id'),
          'refIncome': _s(r, 'refincome'),
          'amount': _money(r, 'amount'),
          'refMoneyType':
              _s(r, 'refmoneytype').isEmpty ? null : _s(r, 'refmoneytype'),
          'detail': _s(r, 'detail'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertExpenseBlock(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'expense');
    for (final r in rows) {
      await txn.insert(
        'expense',
        {
          'id': _s(r, 'id'),
          'server_id': _s(r, 'id'),
          'docno': _s(r, 'docno'),
          'docdate': _ts(r['docdate']),
          'detail': _s(r, 'detail'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'refBudgetSource': _s(r, 'refbudgetsource').isEmpty
              ? null
              : _s(r, 'refbudgetsource'),
          'refExpenseReq':
              _s(r, 'refexpensereq').isEmpty ? null : _s(r, 'refexpensereq'),
          'refParty': _s(r, 'refparty').isEmpty ? null : _s(r, 'refparty'),
          'partyName': _s(r, 'party_name').isEmpty
              ? _s(r, 'partyname')
              : _s(r, 'party_name'),
          'refBankAccount':
              _s(r, 'refbankaccount').isEmpty ? null : _s(r, 'refbankaccount'),
          'docStatus': () {
            final a = _s(r, 'doc_status');
            final b = _s(r, 'docStatus');
            final v = a.isNotEmpty ? a : b;
            return v.isEmpty ? 'posted' : v;
          }(),
          'moneyDomain': () {
            final a = _s(r, 'money_domain');
            final b = _s(r, 'moneyDomain');
            final v = a.isNotEmpty ? a : b;
            return v.isEmpty ? null : v;
          }(),
          'approvedBy': _s(r, 'approved_by').isEmpty
              ? _s(r, 'approvedBy')
              : _s(r, 'approved_by'),
          'approvedAt': _ts(r['approved_at'] ?? r['approvedAt']),
          'postedAt': _ts(r['posted_at'] ?? r['postedAt']),
          'changeReason': _s(r, 'change_reason').isEmpty
              ? _s(r, 'changeReason')
              : _s(r, 'change_reason'),
          'created': _ts(r['created']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final subs = await _pullAllPages(dio, 'expense/sub/');
    for (final r in subs) {
      await txn.insert(
        'expense_sub',
        {
          'id': _s(r, 'id'),
          'refExpense': _s(r, 'refexpense'),
          'refExpenseType':
              _s(r, 'refexpensetype').isEmpty ? null : _s(r, 'refexpensetype'),
          'refFundCategory':
              _s(r, 'refincometype').isEmpty ? null : _s(r, 'refincometype'),
          'refMoneyType':
              _s(r, 'refmoneytype').isEmpty ? null : _s(r, 'refmoneytype'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertExpenseReqBlock(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'expensereq');
    for (final r in rows) {
      await txn.insert(
        'expense_req',
        {
          'id': _s(r, 'id'),
          'server_id': _s(r, 'id'),
          'docno': _s(r, 'docno'),
          'docdate': _ts(r['docdate']),
          'amount': _money(r, 'amount'),
          'detail': _s(r, 'detail'),
          'remark': _s(r, 'remark'),
          'refMember': _s(r, 'refmember').isEmpty ? null : _s(r, 'refmember'),
          'refBudgetSource': _s(r, 'refbudgetsource').isEmpty
              ? null
              : _s(r, 'refbudgetsource'),
          'approval_status': _s(r, 'approval_status').isEmpty
              ? 'draft'
              : _s(r, 'approval_status'),
          'reject_reason':
              _s(r, 'reject_reason').isEmpty ? null : _s(r, 'reject_reason'),
          'member_name':
              _s(r, 'member_name').isEmpty ? null : _s(r, 'member_name'),
          'budget_source_name': _s(r, 'budget_source_name').isEmpty
              ? null
              : _s(r, 'budget_source_name'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final subs = await _pullAllPages(dio, 'expensereq/sub/');
    for (final r in subs) {
      await txn.insert(
        'expense_req_sub',
        {
          'id': _s(r, 'id'),
          'refExpenseReq': _s(r, 'refexpensereq'),
          'refFundCategory':
              _s(r, 'refincometype').isEmpty ? null : _s(r, 'refincometype'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertLoanBlock(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'loan');
    for (final r in rows) {
      final opening = r['opening_outstanding'] ?? r['openingoutstanding'];
      final oo = opening is num
          ? opening.toDouble()
          : double.tryParse(opening?.toString() ?? '') ?? 0.0;
      await txn.insert(
        'loan',
        {
          'id': _s(r, 'id'),
          'docno': _s(r, 'docno'),
          'loandate': _ts(r['loandate']),
          'duedate': _ts(r['duedate']),
          'amount': _money(r, 'amount'),
          'opening_outstanding': oo,
          'remark': _s(r, 'remark'),
          'refMember': _s(r, 'refmember').isEmpty ? null : _s(r, 'refmember'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final subs = await _pullAllPages(dio, 'loan/sub/');
    for (final r in subs) {
      await txn.insert(
        'loan_sub',
        {
          'id': _s(r, 'id'),
          'refLoan': _s(r, 'refloan'),
          'refFundCategory':
              _s(r, 'refincometype').isEmpty ? null : _s(r, 'refincometype'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertRepayBlock(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'repayloan');
    for (final r in rows) {
      await txn.insert(
        'repay_loan',
        {
          'id': _s(r, 'id'),
          'docno': _s(r, 'docno'),
          'duedate': _ts(r['duedate']),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'refLoan': _s(r, 'refloan'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final subs = await _pullAllPages(dio, 'repayloan/sub/');
    for (final r in subs) {
      await txn.insert(
        'repay_loan_sub',
        {
          'id': _s(r, 'id'),
          'refRepayLoan': _s(r, 'refrepayloan'),
          'refFundCategory':
              _s(r, 'refincometype').isEmpty ? null : _s(r, 'refincometype'),
          'amount': _money(r, 'amount'),
          'remark': _s(r, 'remark'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertBankAccounts(Transaction txn, Dio dio) async {
    final bas = await _pullAllPages(dio, 'bankaccount');
    for (final r in bas) {
      await txn.insert(
        'bank_account',
        {
          'id': _s(r, 'id'),
          'accountnumber': _s(r, 'accountnumber'),
          'accountname': _s(r, 'accountname'),
          'sort': int.tryParse(_s(r, 'sort')) ?? 0,
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          'refBank': _s(r, 'refbank'),
          'opening_balance': () {
            final v = r['opening_balance'];
            if (v is num) return v.toDouble();
            return double.tryParse(_s(r, 'opening_balance')) ?? 0.0;
          }(),
          'is_agency_pocket': _boolInt(r, 'is_agency_pocket', 'isagencypocket'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    final ch = await _pullAllPages(dio, 'chequeaccount');
    for (final r in ch) {
      final name = _s(r, 'chequemame').isNotEmpty
          ? _s(r, 'chequemame')
          : _s(r, 'chequename');
      await txn.insert(
        'cheque_account',
        {
          'id': _s(r, 'id'),
          'chequeno': _s(r, 'chequeno'),
          'chequename': name,
          'sort': int.tryParse(_s(r, 'sort')) ?? 0,
          'use': _s(r, 'use').isEmpty ? 'Y' : _s(r, 'use'),
          'refBank': _s(r, 'refbank'),
          'synced': 1,
          'lastModified': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertPayCheques(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'paycheque');
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      await txn.insert(
        'pay_cheque',
        {
          'id': id,
          'chequeamount': _money(r, 'chequeamount'),
          'chequeno': _s(r, 'chequeno'),
          'cleared_at': _ts(r['cleared_at']),
          'remark': _s(r, 'remark'),
          'refChequeAccount': _s(r, 'refchequeaccount').isEmpty
              ? null
              : _s(r, 'refchequeaccount'),
          'refExpense':
              _s(r, 'refexpense').isEmpty ? null : _s(r, 'refexpense'),
          'created': _ts(r['created']),
          'updated': _ts(r['updated']),
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertPartyAllPages(Transaction txn, Dio dio) async {
    final merged = <Map<String, dynamic>>[];
    for (var page = 1; page <= _maxPages; page++) {
      try {
        final resp = await dio.get<dynamic>(
          _u('party'),
          queryParameters: <String, dynamic>{
            'activeOnly': 'false',
            'page': page,
          },
          options: Options(
            receiveTimeout: const Duration(seconds: 45),
            sendTimeout: const Duration(seconds: 15),
          ),
        );
        if (resp.statusCode != 200) break;
        final body = resp.data;
        if (body is! Map) break;
        final data = body['data'] as List? ?? [];
        if (data.isEmpty) break;
        for (final e in data) {
          if (e is Map) merged.add(_norm(Map<dynamic, dynamic>.from(e)));
        }
        if (data.length < _pageHint) break;
      } catch (e) {
        debugPrint('BackupFullMirrorSync: party page $page: $e');
        break;
      }
    }
    final now = DateTime.now().toIso8601String();
    for (final r in merged) {
      final activeRaw = r['isactive'] ?? r['is_active'];
      final isActive = activeRaw == true ||
          activeRaw == 1 ||
          _s(r, 'isactive').toLowerCase() == 'true' ||
          _s(r, 'isactive') == '1';
      await txn.insert(
        'party',
        {
          'id': _s(r, 'id'),
          'name': _s(r, 'name'),
          'role': _s(r, 'role').isEmpty ? 'both' : _s(r, 'role'),
          'phone': _s(r, 'phone'),
          'taxid': _s(r, 'taxid'),
          'remark': _s(r, 'remark'),
          'isactive': isActive ? 1 : 0,
          'synced': 1,
          'lastModified': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<void> _insertDepositGuarantee(Transaction txn, Dio dio) async {
    final rows = await _pullAllPages(dio, 'register/deposits');
    final keepIds = <String>{};
    final now = DateTime.now().toIso8601String();
    for (final r in rows) {
      final id = _s(r, 'id');
      if (id.isEmpty) continue;
      keepIds.add(id);
      await txn.insert(
        'deposit_guarantee',
        {
          'id': id,
          'docno': _s(r, 'docno'),
          'docdate': _ts(r['docdate']).isEmpty ? now : _ts(r['docdate']),
          'deposit_type':
              _s(r, 'deposit_type').isEmpty ? 'other' : _s(r, 'deposit_type'),
          'amount': _money(r, 'amount'),
          'ref_party': _s(r, 'refparty'),
          'party_name_snapshot': _s(r, 'party_name_snapshot').isEmpty
              ? _s(r, 'party_name')
              : _s(r, 'party_name_snapshot'),
          'contract_no': _s(r, 'contract_no'),
          'detail': _s(r, 'detail'),
          'due_date': _ts(r['due_date']),
          'ref_bank_account': _s(r, 'refbankaccount'),
          'status': _s(r, 'status').isEmpty ? 'holding' : _s(r, 'status'),
          'settled_at': _ts(r['settled_at']),
          'settled_docno': _s(r, 'settled_docno'),
          'settled_remark': _s(r, 'settled_remark'),
          'fiscal_year': _s(r, 'fiscal_year'),
          'ref_income_id': _s(r, 'ref_income_id'),
          'ref_expense_id': _s(r, 'ref_expense_id'),
          'income_docno': _s(r, 'income_docno'),
          'expense_docno': _s(r, 'expense_docno'),
          'synced': 1,
          'last_modified': now,
          'updated': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await _pruneRowsNotInServerIds(txn, 'deposit_guarantee', 'id', keepIds);
  }
}
