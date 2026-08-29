// ตรวจ integrity ของไฟล์ binary แบบข้ามแพลตฟอร์ม
//
// เลือก implementation อัตโนมัติ: ใช้ `dart:io` (`integrity_io.dart`) บน
// desktop/mobile และ stub บน Web
export 'integrity_result.dart';
export 'integrity_stub.dart'
    if (dart.library.io) 'integrity_io.dart';
