import 'dart:convert';

import 'package:saccm/config.dart';
import 'package:saccm/core/services/network_info_service.dart';
import 'package:saccm/core/services/sync_service.dart';
import 'package:saccm/core/utils/fiscal_year.dart';
import 'package:saccm/features/register/data/datasources/register_local_data_source.dart';
import 'package:saccm/features/register/data/datasources/register_remote_data_source.dart';

/// Offline-first ทะเบียนเงินประกัน — บันทึก local + คิว sync
class DepositRegisterRepositoryOffline {
  DepositRegisterRepositoryOffline({
    required RegisterRemoteDataSource remote,
    required RegisterLocalDataSource local,
    required NetworkInfoService networkInfo,
    required SyncService syncService,
  })  : _local = local,
        _syncService = syncService;

  final RegisterLocalDataSource _local;
  final SyncService _syncService;

  Future<Map<String, dynamic>> receiveWithIncome({
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final localId = 'local_deposit_${DateTime.now().millisecondsSinceEpoch}';
    final payload = <String, dynamic>{
      ...body,
      'token': token,
      '_localId': localId,
    };

    await _local.upsertDepositFromServer({
      'id': localId,
      'docno': body['docno']?.toString() ?? '',
      'docdate':
          body['docdate']?.toString() ?? DateTime.now().toIso8601String(),
      'deposit_type': body['deposit_type']?.toString() ?? 'contract_guarantee',
      'amount': body['amount'],
      'party_name_snapshot': body['party_name_snapshot'],
      'contract_no': body['contract_no'],
      'detail': body['detail'],
      'due_date': body['due_date'],
      'status': 'holding',
      'fiscal_year': body['fiscal_year']?.toString() ??
          FiscalYear.currentBuddhist().toString(),
      'synced': 0,
    });

    await _syncService.addPendingRequest(
      id: 'deposit_receive_$localId',
      method: 'POST',
      endpoint: '${baseurl}register/deposits/receive-with-income',
      payload: jsonEncode(payload),
    );

    return {
      'status': 'successfully',
      'message': 'บันทึกในเครื่องแล้ว — จะส่งขึ้นเซิร์ฟเวอร์เมื่อออนไลน์',
      'deposit_id': localId,
      'data': await _local.getDepositById(localId),
    };
  }

  Future<Map<String, dynamic>> returnWithExpense({
    required int serverOrLocalId,
    required String localIdHint,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final idStr =
        serverOrLocalId > 0 ? serverOrLocalId.toString() : localIdHint;
    final payload = <String, dynamic>{
      ...body,
      'token': token,
      'create_expense': true,
    };

    await _syncService.addPendingRequest(
      id: 'deposit_return_${idStr}_${DateTime.now().millisecondsSinceEpoch}',
      method: 'POST',
      endpoint: '${baseurl}register/deposits/$idStr/return-with-expense',
      payload: jsonEncode(payload),
    );

    return {
      'status': 'successfully',
      'message': 'คิวคืน/นำส่งแล้ว — จะส่งเมื่อออนไลน์',
    };
  }

  Future<Map<String, dynamic>> updateDeposit({
    required int serverOrLocalId,
    required String localIdHint,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final idStr =
        serverOrLocalId > 0 ? serverOrLocalId.toString() : localIdHint;

    final existing = await _local.getDepositById(idStr);
    if (existing != null) {
      await _local.upsertDepositFromServer({
        ...existing,
        ...body,
        'id': idStr,
        'synced': 0,
      });
    }

    await _syncService.addPendingRequest(
      id: 'deposit_patch_$idStr',
      method: 'PATCH',
      endpoint: '${baseurl}register/deposits/$idStr',
      payload: jsonEncode({...body, 'token': token}),
    );

    return {
      'status': 'successfully',
      'message': 'บันทึกแก้ไขในเครื่องแล้ว — จะส่งเมื่อออนไลน์',
    };
  }

  Future<Map<String, dynamic>> deleteDeposit({
    required String id,
    required String token,
  }) async {
    final row = await _local.getDepositById(id);
    if (row == null) {
      return {'status': 'successfully', 'message': 'ลบข้อมูลในเครื่องแล้ว'};
    }
    if (row['status']?.toString() != 'holding') {
      throw StateError('ลบได้เฉพาะรายการที่ยังถือเงินไว้');
    }

    await _syncService.cancelPendingRequest('deposit_receive_$id');
    await _syncService.cancelPendingRequest('deposit_patch_$id');
    await _local.deleteDepositLocal(id);

    final serverId = int.tryParse(id);
    if (serverId == null) {
      return {
        'status': 'successfully',
        'message': 'ลบรายการในเครื่องแล้ว',
      };
    }

    await _syncService.addPendingRequest(
      id: 'deposit_delete_$id',
      method: 'DELETE',
      endpoint: '${baseurl}register/deposits/$id',
      payload: jsonEncode({'token': token}),
    );
    return {
      'status': 'successfully',
      'message': 'ลบในเครื่องแล้ว — จะส่งขึ้นเซิร์ฟเวอร์เมื่อออนไลน์',
    };
  }

  Future<void> applyReceiveSyncSuccess(
    String localId,
    Map<String, dynamic> response,
  ) async {
    await _applyReceiveSuccess(localId, response);
  }

  Future<void> applyReturnSyncSuccess(Map<String, dynamic> response) async {
    final row = response['data'];
    if (row is Map) {
      await _local.upsertDepositFromServer(Map<String, dynamic>.from(row));
    }
  }

  Future<void> applyPatchSyncSuccess(String depositId) async {
    final row = await _local.getDepositById(depositId);
    if (row == null) return;
    await _local.upsertDepositFromServer({
      ...row,
      'synced': 1,
    });
  }

  Future<void> _applyReceiveSuccess(
    String localId,
    Map<String, dynamic> res,
  ) async {
    final row = res['data'];
    if (row is Map) {
      final m = Map<String, dynamic>.from(row);
      m['income_docno'] ??= res['income_docno'];
      await _local.upsertDepositFromServer(m);
      if (localId.startsWith('local_deposit_')) {
        await _local.deleteDepositLocal(localId);
      }
      return;
    }
    await _local.upsertDepositFromServer({
      'id': res['deposit_id'] ?? res['lastid'] ?? localId,
      'docno': res['income_docno'],
      'income_docno': res['income_docno'],
      'ref_income_id': res['income_id'],
      'status': 'holding',
    });
    if (localId.startsWith('local_deposit_')) {
      final serverId = res['deposit_id'] ?? res['lastid'];
      if (serverId != null) {
        await _local.deleteDepositLocal(localId);
      }
    }
  }
}
