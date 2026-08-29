import 'package:saccm/core/local_data_source/base_local_data_source.dart';

class LocalBankAccountItem {
  final String id;
  final String name;

  const LocalBankAccountItem({required this.id, required this.name});
}

class LocalBankItem {
  final String id;
  final String name;

  const LocalBankItem({required this.id, required this.name});
}

class BankAccountLocalDataSource extends BaseLocalDataSource {
  Future<List<LocalBankItem>> getAllBanks() async {
    final rows = await db.query(
      'bank',
      columns: ['id', 'name'],
      where: 'use IS NULL OR use != ?',
      whereArgs: ['N'],
      orderBy: 'sort ASC, name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (e) => LocalBankItem(
            id: e['id']?.toString() ?? '',
            name: (e['name']?.toString() ?? '').trim(),
          ),
        )
        .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
        .toList();
  }

  Future<List<LocalBankAccountItem>> getAllBankAccounts() async {
    final results = await db.rawQuery(
      '''
      SELECT
        ba.id AS id,
        ba.accountnumber AS accountnumber,
        ba.accountname AS accountname,
        ba.refBank AS refBank,
        b.name AS bankName
      FROM bank_account ba
      LEFT JOIN bank b ON b.id = ba.refBank
      ORDER BY ba.sort ASC, ba.accountname ASC
      ''',
    );
    return results
        .map((e) {
          final bankName =
              (e['bankName'] as String? ?? e['refBank'] as String? ?? '').trim();
          final accountName = (e['accountname'] as String? ?? '').trim();
          final accountNo = (e['accountnumber'] as String? ?? '').trim();
          final base = accountNo.isEmpty
              ? accountName
              : '$accountName ($accountNo)';
          final display = bankName.isEmpty ? base : '$bankName - $base';
          return LocalBankAccountItem(
            id: e['id']?.toString() ?? '',
            name: display.isEmpty ? '-' : display,
          );
        })
        .where((e) => e.id.isNotEmpty)
        .toList();
  }

  Future<String> addBankAccount({
    required String bankId,
    required String accountName,
    required String accountNumber,
    double openingBalance = 0,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await db.insert(
      'bank_account',
      {
        'id': id,
        'accountnumber': accountNumber.trim(),
        'accountname': accountName.trim(),
        'sort': 0,
        'use': 'Y',
        'refBank': bankId,
        'opening_balance': openingBalance,
        'synced': 0,
        'lastModified': DateTime.now().toIso8601String(),
      },
    );
    return id;
  }

  Future<void> markAsSynced(String id) async {
    await db.update(
      'bank_account',
      {
        'synced': 1,
        'lastModified': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
