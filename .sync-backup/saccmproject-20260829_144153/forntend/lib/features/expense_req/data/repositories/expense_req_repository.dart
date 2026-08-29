import 'dart:convert';

import 'package:saccm/config.dart';
import 'package:saccm/core/local_data_source/audit_log_local_data_source.dart';
import 'package:saccm/core/local_data_source/expense_req_local_data_source.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/features/expense_req/data/datasources/expense_req_remote_data_source.dart';

class ExpenseReqRepository {
  ExpenseReqRepository({
    required ExpenseReqLocalDataSource localDataSource,
    required ExpenseReqRemoteDataSource remoteDataSource,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
    AuditLogLocalDataSource? auditLogLocalDataSource,
  })  : _local = localDataSource,
        _sync = syncService,
        _audit = auditLogLocalDataSource;

  final ExpenseReqLocalDataSource _local;
  final SyncService _sync;
  final AuditLogLocalDataSource? _audit;

  Future<List<ExpenseReqModel>> listLocal({String? approvalStatus}) =>
      _local.getAll(approvalStatus: approvalStatus);

  Future<String> createDraft({
    required String token,
    required String docno,
    required String refMember,
    required String memberName,
    required String amount,
    required String detail,
    String? refBudgetSource,
    String? budgetSourceName,
    required List<Map<String, dynamic>> subLines,
    bool silent = false,
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final localId = '${docno}_$ts';
    final now = DateTime.now().toIso8601String();
    final subdataJson = jsonEncode(subLines);

    await _local.saveHeader(
      ExpenseReqModel(
        id: localId,
        docno: docno,
        docdate: now.split('T').first,
        amount: amount,
        detail: detail,
        remark: detail,
        refMember: refMember,
        refBudgetSource: refBudgetSource,
        memberName: memberName,
        budgetSourceName: budgetSourceName,
        approvalStatus: 'draft',
        created: now,
        synced: false,
      ),
    );

    for (var i = 0; i < subLines.length; i++) {
      final line = subLines[i];
      await _local.saveSub(
        ExpenseReqSubModel(
          id: '${localId}_sub_$i',
          refExpenseReq: localId,
          refFundCategory: line['refincometype']?.toString() ?? '',
          amount: line['amount']?.toString() ?? '0',
          remark: line['remark']?.toString(),
        ),
      );
    }

    await _sync.addPendingRequest(
      id: 'expense_req_create_$localId',
      method: 'POST',
      endpoint: '${baseurl}expensereq',
      payload: jsonEncode({
        'token': token,
        'docno': docno,
        'refmember': refMember,
        'remark': detail,
        'detail': detail,
        if (refBudgetSource != null && refBudgetSource.isNotEmpty)
          'refbudgetsource': refBudgetSource,
        'subdata': subdataJson,
        '_localId': localId,
      }),
      silent: silent,
    );

    await _audit?.logEvent(
      module: 'expense_req',
      action: 'create_draft',
      entityId: localId,
      payload: {'docno': docno, 'amount': amount},
    );

    return localId;
  }

  Future<void> submitForApproval({
    required String localId,
    required String token,
    String? note,
  }) async {
    final row = await _local.getById(localId);
    if (row == null) {
      throw Exception('ไม่พบใบขอเบิก');
    }
    if (row.approvalStatus != 'draft') {
      throw Exception('ส่งขออนุมัติได้เฉพาะสถานะร่างเท่านั้น');
    }

    await _sync.addPendingRequest(
      id: 'expense_req_submit_$localId',
      method: 'POST',
      endpoint: '${baseurl}approval/pending/submit',
      payload: jsonEncode({
        'token': token,
        if (note != null && note.isNotEmpty) 'note': note,
        '_localId': localId,
      }),
    );
    await _local.updateApprovalStatus(localId,
        status: 'pending', synced: false);
    await _audit?.logEvent(
      module: 'expense_req',
      action: 'submit',
      entityId: localId,
      payload: {'queued': true},
    );
  }

  Future<void> updateDraft({
    required String localId,
    required String token,
    required String docno,
    required String refMember,
    required String memberName,
    required String amount,
    required String detail,
    String? refBudgetSource,
    String? budgetSourceName,
    required List<Map<String, dynamic>> subLines,
    bool silent = false,
  }) async {
    final row = await _local.getById(localId);
    if (row == null) throw Exception('ไม่พบใบขอเบิก');
    if (row.approvalStatus != 'draft') {
      throw Exception('แก้ไขได้เฉพาะใบขอเบิกสถานะร่าง');
    }
    final now = DateTime.now().toIso8601String();
    final subdataJson = jsonEncode(subLines);
    await _local.saveHeader(
      ExpenseReqModel(
        id: localId,
        serverId: row.serverId,
        docno: docno,
        docdate: row.docdate ?? now.split('T').first,
        amount: amount,
        detail: detail,
        remark: detail,
        refMember: refMember,
        refBudgetSource: refBudgetSource,
        memberName: memberName,
        budgetSourceName: budgetSourceName,
        approvalStatus: 'draft',
        created: row.created,
        synced: false,
      ),
    );
    await _local.replaceSubs(
      localId,
      [
        for (var i = 0; i < subLines.length; i++)
          ExpenseReqSubModel(
            id: '${localId}_sub_$i',
            refExpenseReq: localId,
            refFundCategory: subLines[i]['refincometype']?.toString() ?? '',
            amount: subLines[i]['amount']?.toString() ?? '0',
            remark: subLines[i]['remark']?.toString(),
          ),
      ],
    );

    final serverId = row.serverId?.trim();
    await _sync.addPendingRequest(
      id: serverId == null || serverId.isEmpty
          ? 'expense_req_create_$localId'
          : 'expense_req_update_$localId',
      method: serverId == null || serverId.isEmpty ? 'POST' : 'PATCH',
      endpoint: serverId == null || serverId.isEmpty
          ? '${baseurl}expensereq'
          : '${baseurl}expensereq/$serverId',
      payload: jsonEncode({
        'token': token,
        'docno': docno,
        'refmember': refMember,
        'remark': detail,
        'detail': detail,
        if (refBudgetSource != null && refBudgetSource.isNotEmpty)
          'refbudgetsource': refBudgetSource,
        'subdata': subdataJson,
        '_localId': localId,
      }),
      silent: silent,
    );
  }

  Future<void> deleteDraft({
    required String localId,
    required String token,
  }) async {
    final row = await _local.getById(localId);
    if (row == null) return;
    if (row.approvalStatus != 'draft') {
      throw Exception('ลบได้เฉพาะใบขอเบิกสถานะร่าง');
    }
    await _sync.cancelPendingRequest('expense_req_create_$localId');
    await _sync.cancelPendingRequest('expense_req_update_$localId');
    await _sync.cancelPendingRequest('expense_req_submit_$localId');
    final serverId = row.serverId?.trim();
    await _audit?.logEvent(
      module: 'expense_req',
      action: 'delete',
      entityId: localId,
      payload: {
        'docno': row.docno,
        if (serverId != null && serverId.isNotEmpty) 'server_id': serverId,
      },
    );
    await _local.deleteHeader(localId);
    if (serverId != null && serverId.isNotEmpty) {
      await _sync.addPendingRequest(
        id: 'expense_req_delete_$localId',
        method: 'DELETE',
        endpoint: '${baseurl}expensereq/$serverId',
        payload: jsonEncode({
          'token': token,
          'docno': row.docno,
          '_localId': localId,
        }),
      );
    }
  }

  Future<void> applyCreateSyncSuccess(
    String localId,
    Map<String, dynamic>? response,
  ) async {
    String? serverId;
    if (response != null) {
      for (final k in ['lastid', 'lastId', 'id', 'insertId']) {
        final v = response[k];
        if (v != null && v.toString().isNotEmpty && v != true && v != false) {
          serverId = v.toString();
          break;
        }
      }
    }
    if (serverId != null) {
      await _local.applyServerId(localId, serverId);
    } else {
      await _local.updateApprovalStatus(localId, status: 'draft', synced: true);
    }
  }

  Future<void> applySubmitSyncSuccess(String localId) async {
    await _local.updateApprovalStatus(localId, status: 'pending', synced: true);
  }

  Future<void> applyUpdateSyncSuccess(String localId) async {
    await _local.updateApprovalStatus(localId, status: 'draft', synced: true);
  }

  static String? parseLocalIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    try {
      final m = jsonDecode(payload);
      if (m is Map) return m['_localId']?.toString();
    } catch (_) {}
    return null;
  }
}
