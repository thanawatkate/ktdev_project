import 'dart:ffi';
import 'dart:io';

// kernel32!IsDebuggerPresent -> BOOL (int) ไม่มี argument
typedef _IsDebuggerPresentNative = Int32 Function();
typedef _IsDebuggerPresentDart = int Function();

/// ตรวจว่ามี debugger แนบกับ process หรือไม่ (Windows เท่านั้น)
///
/// ใช้ `IsDebuggerPresent` จาก kernel32 ผ่าน `dart:ffi`
/// (ไม่ต้องพึ่ง allocator ภายนอก) แพลตฟอร์มอื่นคืน false (ไม่บล็อก)
bool isDebuggerAttached() {
  if (!Platform.isWindows) return false;
  try {
    final kernel32 = DynamicLibrary.open('kernel32.dll');
    final isDebuggerPresent = kernel32
        .lookupFunction<_IsDebuggerPresentNative, _IsDebuggerPresentDart>(
      'IsDebuggerPresent',
    );
    return isDebuggerPresent() != 0;
  } catch (_) {
    // โหลด/lookup ไม่ได้ → ถือว่าไม่มี debugger (ไม่บล็อกผิดพลาด)
    return false;
  }
}
