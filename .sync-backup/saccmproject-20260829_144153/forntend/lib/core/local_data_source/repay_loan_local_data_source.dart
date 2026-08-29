import 'package:saccm/core/local_data_source/base_local_data_source.dart';
import 'package:saccm/core/utils/sqlite_money_field.dart';
import 'package:sqflite/sqflite.dart';

class RepayLoanModel {
  final String id;
  final String? serverId;
  final String docno;
  final String duedate;
  final String amount;
  final String remark;
  final String refLoan;
  final String created;
  final bool synced;

  RepayLoanModel({
    required this.id,
    this.serverId,
    required this.docno,
    required this.duedate,
    required this.amount,
    required this.remark,
    required this.refLoan,
    required this.created,
    this.synced = true,
  });

  String get effectiveServerId =>
      serverId?.trim().isNotEmpty == true ? serverId!.trim() : id;
}

class RepayLoanLocalDataSource extends BaseLocalDataSource {
  Future<void> saveRepayLoan(RepayLoanModel item, {bool synced = true}) async {
    await db.insert(
      'repay_loan',
      {
        'id': item.id,
        'server_id': item.serverId,
        'docno': item.docno,
        'duedate': item.duedate,
        'amount': sqliteMoneyToDouble(item.amount),
        'remark': item.remark,
        'refLoan': item.refLoan,
        'created': item.created,
        'updated': DateTime.now().toIso8601String(),
        'synced': synced ? 1 : 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RepayLoanModel>> getAllRepayLoans() async {
    final rows = await db.query('repay_loan', orderBy: 'created DESC');
    return rows
        .map(
          (e) => RepayLoanModel(
            id: e['id'] as String? ?? '',
            serverId: e['server_id']?.toString(),
            docno: e['docno'] as String? ?? '',
            duedate: e['duedate'] as String? ?? '',
            amount: sqliteMoneyToString(e['amount']),
            remark: e['remark'] as String? ?? '',
            refLoan: e['refLoan'] as String? ?? '',
            created: e['created'] as String? ?? '',
            synced: (e['synced'] as int? ?? 1) == 1,
          ),
        )
        .toList();
  }

  Future<RepayLoanModel?> getRepayLoanById(String id) async {
    final rows = await db.query(
      'repay_loan',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final e = rows.first;
    return RepayLoanModel(
      id: e['id'] as String? ?? '',
      serverId: e['server_id']?.toString(),
      docno: e['docno'] as String? ?? '',
      duedate: e['duedate'] as String? ?? '',
      amount: sqliteMoneyToString(e['amount']),
      remark: e['remark'] as String? ?? '',
      refLoan: e['refLoan'] as String? ?? '',
      created: e['created'] as String? ?? '',
      synced: (e['synced'] as int? ?? 1) == 1,
    );
  }

  Future<void> markAsSynced(String id) async {
    await db.update(
      'repay_loan',
      {'synced': 1, 'lastModified': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> applyServerId(String localId, String serverId) async {
    final normalized = serverId.trim();
    if (localId.isEmpty || normalized.isEmpty) return;
    await db.update(
      'repay_loan',
      {
        'server_id': normalized,
        'synced': 1,
        'updated': DateTime.now().toIso8601String(),
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> deleteRepayLoan(String id) async {
    await db.delete('repay_loan', where: 'id = ?', whereArgs: [id]);
  }
}
