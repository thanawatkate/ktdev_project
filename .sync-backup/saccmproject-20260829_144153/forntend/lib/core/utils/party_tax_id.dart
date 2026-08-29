/// ใช้เทียบความซ้ำของเลขผู้เสียภาษี — ตัดช่องว่าง/ขีด แล้วเหลือเฉพาะตัวเลขถ้ามี;
/// ถ้าไม่มีตัวเลขเลย ให้เทียบข้อความ trim + lower (กรณีรูปแบบพิเศษ)
String normalizePartyTaxIdForUniqueness(String input) {
  final t = input.trim();
  if (t.isEmpty) return '';
  final digits = t.replaceAll(RegExp(r'\D'), '');
  if (digits.isNotEmpty) return digits;
  return t.toLowerCase();
}
