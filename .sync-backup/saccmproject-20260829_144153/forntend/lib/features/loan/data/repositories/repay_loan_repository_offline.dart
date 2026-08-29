import 'dart:convert';

import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/repay_loan_local_data_source.dart';
import 'package:saccm/core/services/sync_service.dart';

class RepayLoanRepository {
  final RepayLoanLocalDataSource _localDataSource;
  final AuditLogLocalDataSource? _auditLogLocalDataSource;
  final SyncService _syncService;

  RepayLoanRepository({
    required RepayLoanLocalDataSource localDataSource,
    AuditLogLocalDataSource? auditLogLocalDataSource,
    required SyncService syncService,
  })  : _localDataSource = localDataSource,
        _auditLogLocalDataSource = auditLogLocalDataSource,
        _syncService = syncService;

  Future<List<RepayLoanModel>> getRepayLoanList() =>
      _localDataSource.getAllRepayLoans();

  Future<String> getDocNo({
    required String tableName,
    required String docDate,
  }) async {
    final date = DateTime.tryParse(docDate) ?? DateTime.now();
    final cfg = await _localDataSource.db.query(
      'doc_group',
      columns: ['rungroup', 'docnoformat'],
      where: 'tablename = ?',
      whereArgs: [tableName],
      limit: 1,
    );
    final rungroup = cfg.isEmpty
        ? 'REPAY'
        : (cfg.first['rungroup']?.toString().trim().isNotEmpty == true
            ? cfg.first['rungroup'].toString()
            : 'REPAY');
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
      tableName,
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

  String? _remoteIdForMutation(RepayLoanModel row) {
    final serverId = row.serverId?.trim();
    if (serverId != null && serverId.isNotEmpty) return serverId;
    if (int.tryParse(row.id) != null) return row.id;
    return row.synced && row.docno.trim().isNotEmpty ? row.docno.trim() : null;
  }

  Future<Map<String, String>> _loanServerRef(String refLoan) async {
    final ref = refLoan.trim();
    if (ref.isEmpty) return const {};
    final rows = await _localDataSource.db.query(
      'loan',
      columns: ['id', 'server_id', 'docno'],
      where: 'id = ? OR server_id = ? OR docno = ?',
      whereArgs: [ref, ref, ref],
      limit: 1,
    );
    if (rows.isEmpty) return {'refloan': ref};
    final row = rows.first;
    final serverId = row['server_id']?.toString().trim() ?? '';
    final docno = row['docno']?.toString().trim() ?? '';
    return {
      'refloan':
          serverId.isNotEmpty ? serverId : (docno.isNotEmpty ? docno : ref),
      if (docno.isNotEmpty) 'refloan_docno': docno,
      '_localRefLoan': row['id']?.toString() ?? ref,
    };
  }

  Future<Map<String, dynamic>> _repayPayload({
    required String token,
    required String docno,
    required String refLoan,
    required String amount,
    required String remark,
    required String duedate,
    required String localId,
  }) async {
    return <String, dynamic>{
      'token': token,
      'docno': docno,
      'duedate': duedate,
      'amount': amount,
      'remark': remark,
      ...await _loanServerRef(refLoan),
      '_localId': localId,
    };
  }

  /// คืน id ของแถว `repay_loan` ที่สร้าง (ใช้ rollback / เชื่อมกับขั้นตอนอื่น)
  Future<String> createRepayLoan({
    required String token,
    required String docno,
    required String refLoan,
    required String amount,
    required String remark,
    required String duedate,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final finalDocno = docno.trim().isEmpty
        ? 'TMP-${DateTime.now().toIso8601String().split('T').first.replaceAll('-', '')}-$ts'
        : docno;
    final id = '${finalDocno}_$ts';

    await _localDataSource.saveRepayLoan(
      RepayLoanModel(
        id: id,
        docno: finalDocno,
        duedate: duedate,
        amount: amount,
        remark: remark,
        refLoan: refLoan,
        created: DateTime.now().toIso8601String(),
      ),
      synced: false,
    );

    await _syncService.addPendingRequest(
      id: 'repay_loan_create_$id',
      method: 'POST',
      endpoint: '${baseurl}repayloan',
      payload: jsonEncode(await _repayPayload(
        token: token,
        docno: finalDocno,
        refLoan: refLoan,
        amount: amount,
        remark: remark,
        duedate: duedate,
        localId: id,
      )),
    );

    await _auditLogLocalDataSource?.logEvent(
      module: 'repay_loan',
      action: 'create',
      entityId: id,
      payload: {'docno': finalDocno, 'amount': amount},
    );
    return id;
  }

  Future<void> updateRepayLoan({
    required String localId,
    required String token,
    required String docno,
    required String refLoan,
    required String amount,
    required String remark,
    required String duedate,
    required String created,
  }) async {
    final existing = await _localDataSource.getRepayLoanById(localId);
    final serverId = existing?.serverId;
    await _localDataSource.saveRepayLoan(
      RepayLoanModel(
        id: localId,
        serverId: serverId,
        docno: docno,
        duedate: duedate,
        amount: amount,
        remark: remark,
        refLoan: refLoan,
        created: created,
      ),
      synced: false,
    );

    final remoteId = existing == null ? null : _remoteIdForMutation(existing);
    final isRemoteUpdate = remoteId != null;
    final encodedRemoteId =
        remoteId == null ? null : Uri.encodeComponent(remoteId);
    await _syncService.addPendingRequest(
      id: isRemoteUpdate
          ? 'repay_loan_update_$localId'
          : 'repay_loan_create_$localId',
      method: isRemoteUpdate ? 'PATCH' : 'POST',
      endpoint: isRemoteUpdate
          ? '${baseurl}repayloan/$encodedRemoteId'
          : '${baseurl}repayloan',
      payload: jsonEncode(await _repayPayload(
        token: token,
        docno: docno,
        refLoan: refLoan,
        amount: amount,
        remark: remark,
        duedate: duedate,
        localId: localId,
      )),
    );

    await _auditLogLocalDataSource?.logEvent(
      module: 'repay_loan',
      action: 'update',
      entityId: localId,
      payload: {'docno': docno, 'amount': amount},
    );
  }

  Future<void> deleteRepayLoan({
    required String localId,
    required String token,
    required String docno,
  }) async {
    final existing = await _localDataSource.getRepayLoanById(localId);
    if (existing == null) return;
    await _syncService.cancelPendingRequest('repay_loan_create_$localId');
    await _syncService.cancelPendingRequest('repay_loan_upsert_$localId');
    await _syncService.cancelPendingRequest('repay_loan_update_$localId');
    await _localDataSource.deleteRepayLoan(localId);
    final remoteId = _remoteIdForMutation(existing);
    if (remoteId != null) {
      final encodedRemoteId = Uri.encodeComponent(remoteId);
      await _syncService.addPendingRequest(
        id: 'repay_loan_delete_$localId',
        method: 'DELETE',
        endpoint: '${baseurl}repayloan/$encodedRemoteId',
        payload: jsonEncode({
          'token': token,
          'docno': docno.isNotEmpty ? docno : existing.docno,
        }),
      );
    }

    await _auditLogLocalDataSource?.logEvent(
      module: 'repay_loan',
      action: 'delete',
      entityId: localId,
      payload: {'docno': docno.isNotEmpty ? docno : existing.docno},
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
}
