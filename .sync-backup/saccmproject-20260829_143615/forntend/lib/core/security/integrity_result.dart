/// ผลการตรวจ integrity ของไฟล์ binary
class IntegrityResult {
  final bool ok;

  /// ข้ามการตรวจ (เช่น debug build, ไม่มี manifest, แพลตฟอร์มไม่รองรับ)
  final bool skipped;

  /// รายชื่อไฟล์ที่ผิดปกติ (ถูกแก้/หาย) เมื่อ [ok] == false
  final List<String> offendingFiles;

  /// เหตุผลโดยย่อ (ใช้ log / debug เท่านั้น ห้ามโชว์ผู้ใช้ตรง ๆ)
  final String reason;

  const IntegrityResult._({
    required this.ok,
    required this.skipped,
    required this.offendingFiles,
    required this.reason,
  });

  const IntegrityResult.passed()
      : this._(ok: true, skipped: false, offendingFiles: const [], reason: 'ok');

  const IntegrityResult.skipped(String reason)
      : this._(
          ok: true,
          skipped: true,
          offendingFiles: const [],
          reason: reason,
        );

  const IntegrityResult.failed({
    required List<String> offendingFiles,
    required String reason,
  }) : this._(
          ok: false,
          skipped: false,
          offendingFiles: offendingFiles,
          reason: reason,
        );
}
