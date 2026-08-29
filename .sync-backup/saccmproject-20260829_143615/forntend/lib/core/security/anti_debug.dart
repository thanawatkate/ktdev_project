// ตรวจ debugger แบบข้ามแพลตฟอร์ม
//
// เลือก implementation อัตโนมัติ: ใช้ FFI (`anti_debug_io.dart`) เมื่อมี
// `dart:io` (Windows/desktop/mobile) และ stub บน Web
export 'anti_debug_stub.dart'
    if (dart.library.io) 'anti_debug_io.dart';
