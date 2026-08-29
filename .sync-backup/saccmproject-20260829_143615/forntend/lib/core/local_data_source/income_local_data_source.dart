import 'package:sqflite/sqflite.dart';
import 'package:saccm/core/utils/party_tax_id.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:saccm/features/income/data/models/income_model.dart';
import 'package:saccm/features/income/data/models/lookup_item_model.dart';
import 'base_local_data_source.dart';

class IncomeLocalDataSource extends BaseLocalDataSource {
  static final RegExp _receiptDigitPattern = RegExp(r'\d');
  static final RegExp _receiptDigitRunPattern = RegExp(r'\d+');

  static String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// Rebuilds the next number using the same visible pattern as the book range.
  /// Example: `บร.0001` -> `บร.0002`, `2567/001` -> `2567/002`.
  static String formatReceiptNoLikePattern({
    required String pattern,
    required int value,
  }) {
    final template = pattern.trim();
    final digitWidth = _receiptDigitPattern.allMatches(template).length;
    if (template.isEmpty || digitWidth == 0) return value.toString();

    final valueDigits = value.toString();
    final paddedDigits = valueDigits.padLeft(digitWidth, '0');
    if (paddedDigits.length != digitWidth) {
      final runs = _receiptDigitRunPattern.allMatches(template).toList();
      if (runs.isEmpty) return paddedDigits;
      final lastRun = runs.last;
      final runWidth = lastRun.end - lastRun.start;
      return template.replaceRange(
        lastRun.start,
        lastRun.end,
        valueDigits.padLeft(runWidth, '0'),
      );
    }

    var index = 0;
    return template.replaceAllMapped(
      _receiptDigitPattern,
      (_) => paddedDigits[index++],
    );
  }

  IncomeModel _incomeModelFromRow(Map<String, dynamic> e,
      {bool? syncedOverride}) {
    final syncedVal = syncedOverride ?? ((e['synced'] as int? ?? 1) == 1);
    return IncomeModel(
      id: e['id'] as String? ?? '',
      docno: e['docno'] as String? ?? '',
      docdate: e['docdate'] as String? ?? '',
      detail: e['detail'] as String? ?? '',
      amount: sqliteMoneyToString(e['amount']),
      remark: e['remark'] as String? ?? '',
      bankReference: e['bank_reference'] as String?,
      created: e['created'] as String? ?? '',
      refBudgetSource: e['refBudgetSource'] as String?,
      budgetSourceName: e['budgetSourceName'] as String?,
      refIncomeType: e['refIncomeType'] as String?,
      refParty: e['refParty'] as String?,
      partyName: e['partyName'] as String?,
      refMoneyType: e['refMoneyType'] as String?,
      refBankAccount: e['refBankAccount'] as String?,
      docStatus: e['doc_status'] as String?,
      moneyDomain: e['money_domain'] as String?,
      approvedBy: e['approved_by'] as String?,
      approvedAt: e['approved_at'] as String?,
      postedAt: e['posted_at'] as String?,
      changeReason: e['change_reason'] as String?,
      synced: syncedVal,
    );
  }

  Map<String, Object?> _incomeInsertMap(IncomeModel income,
      {required bool synced}) {
    return {
      'id': income.id,
      'docno': income.docno,
      'docdate': income.docdate,
      'detail': income.detail,
      'amount': sqliteMoneyToDouble(income.amount),
      'remark': income.remark,
      'bank_reference': income.bankReference,
      'created': income.created,
      'refBudgetSource': income.refBudgetSource,
      'refParty': income.refParty,
      'partyName': income.partyName,
      'refMoneyType': income.refMoneyType,
      'refBankAccount': income.refBankAccount,
      'doc_status': income.docStatus ?? 'posted',
      'money_domain': income.moneyDomain,
      'approved_by': income.approvedBy,
      'approved_at': income.approvedAt,
      'posted_at': income.postedAt,
      'change_reason': income.changeReason,
      'synced': synced ? 1 : 0,
      'lastModified': DateTime.now().toIso8601String(),
    };
  }

  /// บันทึก income ลง local database
  /// [executor] ใช้ร่วมกับ [Transaction] เมื่อบันทึกหลายตารางในครั้งเดียว
  Future<void> saveIncome(
    IncomeModel income, {
    bool synced = true,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? db;
    await exec.insert(
      'income',
      _incomeInsertMap(income, synced: synced),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// บันทึก multiple incomes
  Future<void> saveIncomes(List<IncomeModel> incomes) async {
    final deleting = await pendingDeleteProtectionFor('income_delete_');
    final unsyncedRows = await db.query(
      'income',
      columns: ['id'],
      where: 'synced = 0',
    );
    final protectedIds = unsyncedRows
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    final batch = db.batch();
    for (final income in incomes) {
      if (protectedIds.contains(income.id) ||
          deleting.protects(id: income.id, docno: income.docno)) {
        continue;
      }
      batch.insert(
        'income',
        _incomeInsertMap(income, synced: true),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit();
  }

  /// ดึง income ทั้งหมดจาก local database
  Future<List<IncomeModel>> getAllIncomes() async {
    final results = await db.rawQuery('''
      SELECT
        i.*,
        (
          SELECT s.refIncomeType
          FROM income_sub s
          WHERE s.refIncome = i.id
          ORDER BY s.id ASC
          LIMIT 1
        ) AS refIncomeType,
        bm.name AS budgetSourceName
      FROM income i
      LEFT JOIN budget_source_budget bb ON bb.id = i.refBudgetSource
      LEFT JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
      ORDER BY i.docdate DESC
    ''');
    return results.map((e) => _incomeModelFromRow(e)).toList();
  }

  Future<({double total, int count})> getDashboardSummaryTotals() async {
    final rows = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CAST(amount AS REAL)), 0) AS total,
        COUNT(*) AS count
      FROM income
    ''');
    final row = rows.first;
    final total = (row['total'] as num?)?.toDouble() ??
        double.tryParse(row['total']?.toString() ?? '0') ??
        0.0;
    final count = (row['count'] as num?)?.toInt() ??
        int.tryParse(row['count']?.toString() ?? '0') ??
        0;
    return (total: total, count: count);
  }

  Future<Map<String, double>> getDashboardMonthlyTotals({
    required String startMonth,
  }) async {
    final rows = await db.rawQuery('''
      SELECT
        substr(docdate, 1, 7) AS month_key,
        COALESCE(SUM(CAST(amount AS REAL)), 0) AS total
      FROM income
      WHERE docdate >= ?
      GROUP BY substr(docdate, 1, 7)
    ''', ['$startMonth-01']);
    return {
      for (final row in rows)
        row['month_key']?.toString() ?? '':
            (row['total'] as num?)?.toDouble() ??
                double.tryParse(row['total']?.toString() ?? '0') ??
                0.0,
    }..remove('');
  }

  /// ดึง income ตาม id
  Future<IncomeModel?> getIncomeById(String id) async {
    final results = await db.rawQuery('''
      SELECT
        i.*,
        (
          SELECT s.refIncomeType
          FROM income_sub s
          WHERE s.refIncome = i.id
          ORDER BY s.id ASC
          LIMIT 1
        ) AS refIncomeType,
        bm.name AS budgetSourceName
      FROM income i
      LEFT JOIN budget_source_budget bb ON bb.id = i.refBudgetSource
      LEFT JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
      WHERE i.id = ?
      LIMIT 1
    ''', [id]);

    if (results.isEmpty) return null;

    return _incomeModelFromRow(results.first);
  }

  LookupItemModel _budgetSourceLookupFromRow(Map<String, Object?> row) {
    return LookupItemModel(
      id: row['id']?.toString() ?? '',
      name: row['name']?.toString() ?? '',
      refFundCategory: row['refFundCategory']?.toString(),
      refBankAccount: row['refBankAccount']?.toString(),
    );
  }

  /// แหล่งเงินทั้งหมดสำหรับ legacy call sites ที่ยังต้องการ preload ทั้งรายการ
  Future<List<LookupItemModel>> getBudgetSourceLookups() async {
    final rows = await db.rawQuery('''
      SELECT
        bb.id,
        bm.name,
        bm.refFundCategory,
        bm.refBankAccount
      FROM budget_source_budget bb
      INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
      ORDER BY bm.name ASC
    ''');
    return rows.map(_budgetSourceLookupFromRow).toList();
  }

  /// แหล่งเงินที่ผูกกับหมวดรายรับหนึ่งหมวดเท่านั้น ลดการโหลด dropdown ขนาดใหญ่
  Future<List<LookupItemModel>> getBudgetSourceLookupsForIncomeType(
    String incomeTypeId,
  ) async {
    final id = incomeTypeId.trim();
    if (id.isEmpty) return const <LookupItemModel>[];
    final rows = await db.rawQuery('''
      SELECT DISTINCT
        bb.id,
        bm.name,
        bm.code,
        COALESCE(map.refIncomeType, bm.refFundCategory) AS refFundCategory,
        bm.refBankAccount
      FROM budget_source_budget bb
      INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
      LEFT JOIN income_type_budget_source_map map
        ON map.refBudgetSourceMaster = bm.id
       AND map.refIncomeType = ?
      WHERE map.refIncomeType = ?
         OR bm.refFundCategory = ?
      ORDER BY bm.name ASC
    ''', [id, id, id]);
    final hasCategorySpecificSource = rows.any((row) {
      final code = row['code']?.toString().trim().toUpperCase() ?? '';
      return code != 'GOV' && code != 'NONGOV';
    });
    final visibleRows = hasCategorySpecificSource
        ? rows.where((row) {
            final code = row['code']?.toString().trim().toUpperCase() ?? '';
            return code != 'GOV' && code != 'NONGOV';
          })
        : rows;
    return visibleRows.map(_budgetSourceLookupFromRow).toList();
  }

  /// หา context ของ budget row เดียว ใช้ตอน edit ที่มี refBudgetSource อยู่แล้ว
  Future<LookupItemModel?> getBudgetSourceLookupById(
      String budgetSourceId) async {
    final id = budgetSourceId.trim();
    if (id.isEmpty) return null;
    final rows = await db.rawQuery('''
      SELECT
        bb.id,
        bm.name,
        COALESCE(bm.refFundCategory, map.refIncomeType) AS refFundCategory,
        bm.refBankAccount
      FROM budget_source_budget bb
      INNER JOIN budget_source_master bm ON bm.id = bb.refBudgetSourceMaster
      LEFT JOIN income_type_budget_source_map map
        ON map.refBudgetSourceMaster = bm.id
      WHERE bb.id = ?
      ORDER BY
        CASE
          WHEN bm.refFundCategory IS NOT NULL
           AND bm.refFundCategory = map.refIncomeType THEN 0
          ELSE 1
        END
      LIMIT 1
    ''', [id]);
    if (rows.isEmpty) return null;
    return _budgetSourceLookupFromRow(rows.first);
  }

  /// ลบ income จาก local database
  Future<void> deleteIncome(String id) async {
    await db.delete('income', where: 'id = ?', whereArgs: [id]);
  }

  /// ล้าง income ทั้งหมด
  Future<void> clearAllIncomes() async {
    await db.delete('income');
  }

  /// ดึง pending incomes (ที่ยังไม่ได้ sync)
  Future<List<IncomeModel>> getPendingIncomes() async {
    final results = await db.query(
      'income',
      where: 'synced = 0',
    );
    return results
        .map((e) => _incomeModelFromRow(e, syncedOverride: false))
        .toList();
  }

  /// Mark income as synced
  Future<void> markAsSynced(String id) async {
    await db.update(
      'income',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// แถว party เดียว (สำหรับ offline-first)
  Future<void> upsertPartyRow({
    required String id,
    required String name,
    required String role,
    String? phone,
    String? taxid,
    String? remark,
    required bool isActive,
    required int synced,
  }) async {
    await db.insert(
      'party',
      {
        'id': id,
        'name': name,
        'role': role.toLowerCase(),
        'phone': phone,
        'taxid': taxid,
        'remark': remark,
        'isactive': isActive ? 1 : 0,
        'synced': synced,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// แม็ป id ชั่วคราว (`lp_...`) → id จากเซิร์ฟเวอร์ พร้อมอัปเดต ref ใน income/expense
  Future<void> replacePartyPrimaryKey(String oldId, String newId) async {
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE income SET refParty = ? WHERE refParty = ?',
        [newId, oldId],
      );
      await txn.rawUpdate(
        'UPDATE expense SET refParty = ? WHERE refParty = ?',
        [newId, oldId],
      );
      final rows = await txn.query(
        'party',
        where: 'id = ?',
        whereArgs: [oldId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      final m = Map<String, dynamic>.from(rows.first);
      await txn.delete('party', where: 'id = ?', whereArgs: [oldId]);
      m['id'] = newId;
      m['synced'] = 1;
      m['lastModified'] = DateTime.now().toIso8601String();
      await txn.insert('party', m,
          conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> markPartySynced(String partyId) async {
    await db.update(
      'party',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [partyId],
    );
  }

  Future<Map<String, dynamic>?> getPartyRow(String id) async {
    final rows = await db.query(
      'party',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  /// คืนแถว party แรกที่เลขผู้เสียภาษี (หลัง normalize) ตรงกับ [taxIdRaw] แต่ไม่ใช่ [excludePartyId]
  Future<Map<String, dynamic>?> findPartyRowWithConflictingTaxId({
    required String taxIdRaw,
    String? excludePartyId,
  }) async {
    final key = normalizePartyTaxIdForUniqueness(taxIdRaw);
    if (key.isEmpty) return null;
    final rows = await db.query('party', columns: ['id', 'name', 'taxid']);
    for (final r in rows) {
      final id = r['id']?.toString() ?? '';
      if (excludePartyId != null && id == excludePartyId) continue;
      final t = r['taxid']?.toString() ?? '';
      if (normalizePartyTaxIdForUniqueness(t) == key) return r;
    }
    return null;
  }

  /// ลบ master `party` — FK จัด `income`/`expense`.`refParty`, `party_audit_server_line`.`ref_party_record_id` (SET NULL),
  /// `party_audit_scope` + บรรทัด audit แคช (CASCADE จาก `scope_party_id` เมื่อ db v31+)
  Future<void> deletePartyById(String partyId) async {
    await db.delete('party', where: 'id = ?', whereArgs: [partyId]);
  }

  /// เล่มใบเสร็จที่ยังใช้ได้ (สถานะ `available`) — สำหรับฟอร์มรับเงิน
  Future<List<Map<String, dynamic>>> listAvailableReceiptBooks() async {
    final rows = await db.query(
      'receipt_book',
      where: 'LOWER(TRIM(status)) = ?',
      whereArgs: ['available'],
      orderBy: 'fiscal_year DESC, book_no ASC',
    );
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<String?> suggestedNextReceiptNo(String bookId) async {
    final books = await db.query(
      'receipt_book',
      where: 'id = ?',
      whereArgs: [bookId],
      limit: 1,
    );
    if (books.isEmpty) return null;
    final book = books.first;
    final startRaw = book['start_no']?.toString().trim() ?? '';
    final startNo = int.tryParse(_digitsOnly(startRaw));
    if (startNo == null) return null;

    final issues = await db.query(
      'receipt_issue',
      columns: ['receipt_no'],
      where: 'ref_book = ?',
      whereArgs: [bookId],
    );
    var maxIssued = 0;
    for (final row in issues) {
      final n = int.tryParse(
        _digitsOnly(row['receipt_no']?.toString() ?? ''),
      );
      if (n != null && n > maxIssued) maxIssued = n;
    }

    final expected = maxIssued == 0 ? startNo : maxIssued + 1;
    return formatReceiptNoLikePattern(pattern: startRaw, value: expected);
  }
}
