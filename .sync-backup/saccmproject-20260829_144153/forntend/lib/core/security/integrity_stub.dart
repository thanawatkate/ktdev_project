// Stub สำหรับแพลตฟอร์มที่ไม่มี `dart:io` (Web)
// — ไม่มีไฟล์ binary ให้ตรวจ จึงผ่านเสมอ
import 'integrity_result.dart';

Future<IntegrityResult> verifyBinaryIntegrity() async =>
    const IntegrityResult.skipped('platform-unsupported');
