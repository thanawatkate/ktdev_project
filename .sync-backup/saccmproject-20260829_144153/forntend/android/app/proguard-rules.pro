# ProGuard/R8 rules สำหรับ SACCM release
#
# Flutter engine + embedding ต้องคงไว้ ไม่ให้ R8 ตัด/เปลี่ยนชื่อ
# (Dart code ถูก obfuscate แยกผ่าน flutter build --obfuscate อยู่แล้ว)
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# คงชื่อ entrypoint ของ Application/Activity ที่ manifest อ้างถึง
-keep class com.saccm.app.** { *; }

# ลบ log call ตอน release เพื่อไม่ให้หลุดข้อมูลและลด string ที่อ่านได้
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}
