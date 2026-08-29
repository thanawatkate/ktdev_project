import 'dart:convert';

import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/loan_local_data_source.dart';
import 'package:saccm/core/services/sync_service.dart';

/// รายการย่อยสำหรับบันทึก — ส่งเป็น `subdata` (คีย์ refincometype) ตาม API
class LoanSubLineInput {
  const LoanSubLineInput({
    required this.refFundCategory,
    required this.amount,
    this.remark = '',
  });

  final String refFundCategory;
  final String amount;
  final String remark;
}

class LoanRepository {
  final LoanLocalDataSource _localDataSource;
  final AuditLogLocalDataSource? _auditLogLocalDataSource;
  final SyncService _syncService;

  LoanRepository({
    required LoanLocalDataSource localDataSource,
    AuditLogLocalDataSource? auditLogLocalDataSource,
    required SyncService syncService,
  })  : _localDataSource = localDataSource,
        _auditLogLocalDataSource = auditLogLocalDataSource,
        _syncService = syncService;

  Future<List<LoanModel>> getLoanList() => _localDataSource.getAllLoans();

  Future<String> getDocNo({
    required String tableName,
    required String docDate,
  }) async {
    final localTableName = _localDocNoTableName(tableName);
    final date = DateTime.tryParse(docDate) ?? DateTime.now();
    final cfg = await _localDataSource.db.query(
      'doc_group',
      columns: ['rungroup', 'docnoformat'],
      where: 'tablename = ?',
      whereArgs: [localTableName],
      limit: 1,
    );
    final rungroup = cfg.isEmpty
        ? _defaultRunGroup(localTableName)
        : (cfg.first['rungroup']?.toString().trim().isNotEmpty == true
            ? cfg.first['rungroup'].toString()
            : _defaultRunGroup(localTableName));
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
    final escaped = RegExp.escape(baseWithMarker).replaceAll(marker, r'(\d+)');
    final regex = RegExp('^$escaped\$');
    final docs = await _localDataSource.db.query(
      localTableName,
      columns: ['docno'],
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
    return _resolveFormat(
      format: rawFormat,
      rungroup: rungroup,
      date: date,
      runText: runText,
    );
  }

  String _localDocNoTableName(String tableName) {
    switch (tableName.trim().toLowerCase()) {
      case 'expensereq':
        return 'expense_req';
      default:
        return tableName;
    }
  }

  String _defaultRunGroup(String tableName) {
    switch (tableName.trim().toLowerCase()) {
      case 'expense_req':
        return 'REQ';
      default:
        return 'LOAN';
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

  double _parseMoney(String s) =>
      double.tryParse(s.trim().replaceAll(',', '')) ?? 0;

  List<LoanSubLineInput> _normalizeSubLines(List<LoanSubLineInput> raw) {
    final out = <LoanSubLineInput>[];
    for (final e in raw) {
      final a = _parseMoney(e.amount);
      if (a <= 0) continue;
      final cat = e.refFundCategory.trim();
      if (cat.isEmpty) continue;
      out.add(LoanSubLineInput(
        refFundCategory: cat,
        amount: a.toString(),
        remark: e.remark.trim(),
      ));
    }
    return out;
  }

  String _loanPrincipalString(List<LoanSubLineInput> normalized) {
    final sum = normalized.fold<double>(0, (s, e) => s + _parseMoney(e.amount));
    if (sum <= 0) return '0';
    return sum.toString();
  }

  String? _encodeLoanSubdata(List<LoanSubLineInput> normalized) {
    if (normalized.isEmpty) return null;
    return jsonEncode(
      normalized
          .map(
            (e) => <String, dynamic>{
              'refincometype': e.refFundCategory,
              'amount': e.amount,
              'remark': e.remark,
            },
          )
          .toList(),
    );
  }

  String? _serverIdFromResponse(Map<String, dynamic>? response) {
    if (response == null) return null;
    for (final key in ['lastId', 'lastid', 'id', 'insertId']) {
      final v = response[key];
      if (v == null || v == true || v == false) continue;
      final text = v.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String? _remoteIdForMutation(LoanModel row) {
    final serverId = row.serverId?.trim();
    if (serverId != null && serverId.isNotEmpty) return serverId;
    if (int.tryParse(row.id) != null) return row.id;
    return row.synced && row.docno.trim().isNotEmpty ? row.docno.trim() : null;
  }

  Map<String, dynamic> _loanPayload({
    required String token,
    required String docno,
    required String loandate,
    required String duedate,
    required String principalStr,
    required double openingOutstanding,
    required String remark,
    required String borrower,
    required String localId,
    required List<LoanSubLineInput> normalized,
  }) {
    final payload = <String, dynamic>{
      'token': token,
      'docno': docno,
      'loandate': loandate,
      'duedate': duedate,
      'amount': principalStr,
      'opening_outstanding': openingOutstanding,
      'remark': remark,
      'refmember': borrower,
      '_localId': localId,
    };
    final subEnc = _encodeLoanSubdata(normalized);
    if (subEnc != null) {
      payload['subdata'] = subEnc;
    }
    return payload;
  }

  Future<List<LoanSubPersistRow>> getLoanSubRows(String loanId) =>
      _localDataSource.getLoanSubs(loanId);

  Future<void> createLoan({
    required String token,
    required String docno,
    required String borrower,
    double openingOutstanding = 0,
    required String remark,
    required String loandate,
    required String duedate,
    List<LoanSubLineInput> subLines = const [],
  }) async {
    final normalized = _normalizeSubLines(subLines);
    final principalStr = _loanPrincipalString(normalized);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final finalDocno = docno.trim().isEmpty
        ? 'TMP-${DateTime.now().toIso8601String().split('T').first.replaceAll('-', '')}-$ts'
        : docno;
    final loanId = '${finalDocno}_$ts';

    await _localDataSource.saveLoan(
      LoanModel(
        id: loanId,
        docno: finalDocno,
        loandate: loandate,
        duedate: duedate,
        amount: principalStr,
        openingOutstanding: openingOutstanding,
        remark: remark,
        refMember: borrower,
        borrowerDisplay: '',
        created: DateTime.now().toIso8601String(),
      ),
      synced: false,
    );

    await _localDataSource.replaceLoanSubs(
      loanId,
      normalized
          .map(
            (e) => LoanSubPersistRow(
              id: '',
              refLoan: loanId,
              refFundCategory: e.refFundCategory,
              amount: _parseMoney(e.amount),
              remark: e.remark,
              created: '',
            ),
          )
          .toList(),
      synced: false,
    );

    await _syncService.addPendingRequest(
      id: 'loan_create_$loanId',
      method: 'POST',
      endpoint: '${baseurl}loan',
      payload: jsonEncode(
        _loanPayload(
          token: token,
          docno: finalDocno,
          loandate: loandate,
          duedate: duedate,
          principalStr: principalStr,
          openingOutstanding: openingOutstanding,
          remark: remark,
          borrower: borrower,
          localId: loanId,
          normalized: normalized,
        ),
      ),
    );

    await _auditLogLocalDataSource?.logEvent(
      module: 'loan',
      action: 'create',
      entityId: loanId,
      payload: {
        'docno': finalDocno,
        'amount': principalStr,
      },
    );
  }

  Future<void> updateLoan({
    required String localId,
    required String token,
    required String docno,
    required String borrower,
    double openingOutstanding = 0,
    required String remark,
    required String loandate,
    required String duedate,
    required String created,
    List<LoanSubLineInput> subLines = const [],
  }) async {
    final normalized = _normalizeSubLines(subLines);
    final principalStr = _loanPrincipalString(normalized);
    final existing = await _localDataSource.getLoanById(localId);
    final serverId = existing?.serverId;

    await _localDataSource.saveLoan(
      LoanModel(
        id: localId,
        serverId: serverId,
        docno: docno,
        loandate: loandate,
        duedate: duedate,
        amount: principalStr,
        openingOutstanding: openingOutstanding,
        remark: remark,
        refMember: borrower,
        borrowerDisplay: '',
        created: created,
      ),
      synced: false,
    );

    await _localDataSource.replaceLoanSubs(
      localId,
      normalized
          .map(
            (e) => LoanSubPersistRow(
              id: '',
              refLoan: localId,
              refFundCategory: e.refFundCategory,
              amount: _parseMoney(e.amount),
              remark: e.remark,
              created: '',
            ),
          )
          .toList(),
      synced: false,
    );

    final remoteId = existing == null ? null : _remoteIdForMutation(existing);
    final isRemoteUpdate = remoteId != null;
    final encodedRemoteId =
        remoteId == null ? null : Uri.encodeComponent(remoteId);

    await _syncService.addPendingRequest(
      id: isRemoteUpdate ? 'loan_update_$localId' : 'loan_create_$localId',
      method: isRemoteUpdate ? 'PATCH' : 'POST',
      endpoint:
          isRemoteUpdate ? '${baseurl}loan/$encodedRemoteId' : '${baseurl}loan',
      payload: jsonEncode(
        _loanPayload(
          token: token,
          docno: docno,
          loandate: loandate,
          duedate: duedate,
          principalStr: principalStr,
          openingOutstanding: openingOutstanding,
          remark: remark,
          borrower: borrower,
          localId: localId,
          normalized: normalized,
        ),
      ),
    );

    await _auditLogLocalDataSource?.logEvent(
      module: 'loan',
      action: 'update',
      entityId: localId,
      payload: {
        'docno': docno,
        'amount': principalStr,
      },
    );
  }

  Future<void> deleteLoan({
    required String localId,
    required String token,
    required String docno,
  }) async {
    final existing = await _localDataSource.getLoanById(localId);
    if (existing == null) return;
    await _syncService.cancelPendingRequest('loan_create_$localId');
    await _syncService.cancelPendingRequest('loan_upsert_$localId');
    await _syncService.cancelPendingRequest('loan_update_$localId');
    await _localDataSource.deleteLoan(localId);
    final remoteId = _remoteIdForMutation(existing);
    if (remoteId != null) {
      final encodedRemoteId = Uri.encodeComponent(remoteId);
      await _syncService.addPendingRequest(
        id: 'loan_delete_$localId',
        method: 'DELETE',
        endpoint: '${baseurl}loan/$encodedRemoteId',
        payload: jsonEncode({
          'token': token,
          'docno': docno.isNotEmpty ? docno : existing.docno,
        }),
      );
    }

    await _auditLogLocalDataSource?.logEvent(
      module: 'loan',
      action: 'delete',
      entityId: localId,
      payload: {
        'docno': docno.isNotEmpty ? docno : existing.docno,
      },
    );
  }

  Future<void> applyCreateSyncSuccess(
    String localId,
    Map<String, dynamic>? response,
  ) async {
    final serverId = _serverIdFromResponse(response);
    if (serverId != null) {
      await _localDataSource.applyServerId(localId, serverId);
      return;
    }
    await _localDataSource.markAsSynced(localId);
  }

  Future<void> applyUpdateSyncSuccess(String localId) async {
    await _localDataSource.markAsSynced(localId);
  }

  Future<Map<String, dynamic>?> findActiveOutstandingLoanByBorrower(
    String borrower, {
    String? excludeLoanId,
  }) {
    return _localDataSource.findActiveOutstandingLoanByBorrower(
      borrower,
      excludeLoanId: excludeLoanId,
    );
  }
}
