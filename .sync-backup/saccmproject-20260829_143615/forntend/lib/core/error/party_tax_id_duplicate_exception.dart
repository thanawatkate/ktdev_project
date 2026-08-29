/// บันทึกผู้รับ/ผู้จ่ายแล้วเลขผู้เสียภาษี (หลัง normalize) ซ้ำกับแถวอื่นใน localdb
class PartyTaxIdDuplicateException implements Exception {
  PartyTaxIdDuplicateException(this.otherPartyName);

  final String otherPartyName;

  @override
  String toString() =>
      'เลขผู้เสียภาษีซ้ำกับผู้เกี่ยวข้อง: ${otherPartyName.trim().isEmpty ? '(ไม่มีชื่อ)' : otherPartyName.trim()}';
}
