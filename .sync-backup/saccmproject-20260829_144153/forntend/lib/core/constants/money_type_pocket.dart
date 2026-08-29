/// แมป `money_type` (code/name) → pocket ตาม canonical rule (`.cursor/rules/10-saccm-domain-core.mdc` §7)
///
/// ใช้ร่วมกันใน:
/// - `RegisterLocalDataSource._classifyPocket` (ทะเบียน + รายงาน)
/// - `ExpenseAddPage` (สลับ flow เก็บข้อมูลเช็ค/บัญชีธนาคาร)
abstract final class MoneyTypePocket {
  MoneyTypePocket._();

  static const String cash = 'cash';
  static const String bank = 'bank';
  static const String agency = 'agency';

  /// เลือก code ก่อน (เป็น stable key) — ถ้าว่างค่อย fallback ไปดูชื่อ
  static String classify({String? code, String? name}) {
    final c = (code ?? '').trim().toUpperCase();
    if (c == 'CASH') return cash;
    if (c == 'CHEQUE' || c == 'TRANSFER' || c == 'BANK') return bank;
    if (c == 'AGENCY') return agency;

    final n = (name ?? '').toLowerCase();
    if (n.contains('ส่วนราชการ') || n.contains('agency')) return agency;
    if (n.contains('โอน') ||
        n.contains('ฝากธนาคาร') ||
        n.contains('bank') ||
        n.contains('transfer') ||
        n.contains('เช็ค') ||
        n.contains('cheque')) {
      return bank;
    }
    return cash;
  }

  /// คืน true เมื่อ money_type เป็นการจ่ายโดยเช็คโดยเฉพาะ
  /// (ใช้แสดง section เก็บข้อมูลเช็คเพิ่มเติม)
  static bool isCheque({String? code, String? name}) {
    final c = (code ?? '').trim().toUpperCase();
    if (c == 'CHEQUE') return true;
    final n = (name ?? '').toLowerCase();
    return n.contains('เช็ค') || n.contains('cheque');
  }
}
