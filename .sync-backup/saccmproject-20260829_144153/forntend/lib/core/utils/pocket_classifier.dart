/// จำแนกช่องทางเงิน (เงินสด / ธนาคาร / ส่วนราชการผู้เบิก) จากชื่อ `money_type`
/// ให้สอดคล้องกับ `RegisterLocalDataSource._classifyPocket` เดิม
class PocketClassifier {
  PocketClassifier._();

  static const pocketCash = 'cash';
  static const pocketBank = 'bank';
  static const pocketAgency = 'agency';

  static String pocketKey(String? moneyTypeName) {
    final name = (moneyTypeName ?? '').toLowerCase();
    if (name.contains('ส่วนราชการ') ||
        name.contains('agency') ||
        name.contains('agent')) {
      return pocketAgency;
    }
    if (name.contains('เช็ค') ||
        name.contains('ธนาคาร') ||
        name.contains('ฝาก') ||
        name.contains('โอน') ||
        name.contains('ตั๋ว') ||
        name.contains('bank') ||
        name.contains('cheque') ||
        name.contains('transfer')) {
      return pocketBank;
    }
    return pocketCash;
  }
}
