/// Key ใน SharedPreferences — คัดลอกไฟล์สำรองไปแล้ว รอแทนที่ saccm.db ตอนเปิดแอปรอบถัดไป
const String kPendingSaccmDbRestorePathKey = 'pending_saccm_db_restore_path';

/// Web ไม่มีไฟล์ `saccm.db` ให้แทนที่โดยตรง เพราะฐานข้อมูลอยู่ใน browser storage.
Future<void> applyPendingSaccmDbRestoreIfAny() async {}
