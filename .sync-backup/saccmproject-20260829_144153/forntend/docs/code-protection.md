# ระบบกันแกะโค๊ด (Code Protection) — SACCM Windows

> ขอบเขต: Windows desktop build ของ `forntend/` (Flutter)
> ระดับการป้องกัน: กัน "แกะ/แก้แบบทั่วไป" (casual tampering & reverse engineering)
> ไม่ใช่การป้องกันระดับ DRM/ผู้โจมตีที่มีทรัพยากรไม่จำกัด

ระบบนี้ออกแบบแบบ **fail-safe**: ถ้าตรวจไม่ได้หรือยังไม่ได้ทำ protected packaging
(เช่น debug build, ไม่มี manifest) แอปจะ **ไม่บล็อก** ผู้ใช้ — บล็อกเฉพาะเมื่อ
พบหลักฐานชัดเจนว่าถูกแก้ไฟล์หรือถูกแกะเท่านั้น เพื่อลด false positive

---

## 1. ชั้นการป้องกัน (defense in depth)

| ชั้น | กันอะไร | ไฟล์หลัก |
|---|---|---|
| Dart obfuscation | อ่าน/ไล่โค๊ดจาก binary | `tool/build_windows_protected.ps1` (`--obfuscate`) |
| Binary integrity | แก้ไฟล์ `.exe` / `.dll` แล้วรันต่อ | `lib/core/security/binary_integrity.dart` + manifest |
| Anti-debug (Dart) | แนบ debugger ตอน runtime | `lib/core/security/anti_debug.dart` |
| Anti-debug (native) | แนบ debugger ก่อน Flutter เริ่ม | `windows/runner/main.cpp` |
| Tamper-evident store | แก้ค่า trial/license ในไฟล์/secure storage ด้วยมือ | `lib/core/services/redundant_local_store.dart` (HMAC) |
| Orchestrator + UI gate | รวมผลตรวจ + บล็อกหน้าจอ | `lib/core/security/app_guard.dart`, `app_guard_gate.dart` |

ลำดับการทำงานตอนเปิดแอป:

1. `windows/runner/main.cpp` → ตรวจ debugger ระดับ native (เฉพาะ release) ออกทันทีถ้าพบ
2. `main()` ใน `lib/main.dart` → เรียก `AppGuard.run()` ก่อน `runApp`
3. `AppGuard` → ตรวจ integrity ของไฟล์ + ตรวจ debugger (Dart)
4. `AppGuardGate` (ครอบทั้งแอป) → ถ้าไม่ผ่านแสดงหน้าบล็อก และตรวจ debugger ซ้ำเป็นระยะ

---

## 2. คีย์ลับ (embedded secrets)

อยู่ใน `lib/core/security/guard_secret.dart`:

- `storeSecretHex` — เซ็นค่าใน trial/license local store (กันแก้มือ)
- `integritySecretHex` — เซ็น integrity manifest (กันแก้รายการ hash)

> ค่าพวกนี้ถูกซ่อนด้วย Dart obfuscation ตอน build release
> **`integritySecretHex` ต้องตรงกับ `$IntegritySecretHex` ใน
> `tool/build_windows_protected.ps1` เสมอ** ไม่งั้น integrity จะ fail ตลอด

การหมุนคีย์ (rotate): แก้ค่าในทั้งสองที่ → build ใหม่ → สร้าง manifest ใหม่

---

## 3. Integrity manifest

สร้างโดย `tool/build_windows_protected.ps1` วางไว้ข้าง `saccm.exe`
ชื่อ `integrity_manifest.json`:

```json
{
  "version": 1,
  "files": {
    "flutter_windows.dll": "<sha256hex>",
    "saccm.exe": "<sha256hex>"
  },
  "signature": "<hmac-sha256 ของ canonical(files)>"
}
```

- canonical string = `key=hash;` เรียงตามคีย์ (ตรงกันทั้งฝั่ง Dart และ PowerShell)
- ตอนรัน: ตรวจ `signature` ก่อน แล้วค่อยเทียบ SHA-256 ของไฟล์จริงทีละไฟล์
- ไฟล์ที่ตรวจอยู่ใน `$ProtectedFiles` ของสคริปต์ (ปัจจุบัน: `saccm.exe`,
  `flutter_windows.dll`) — เพิ่มได้ตามต้องการ แต่ใส่เฉพาะไฟล์ที่ "ไม่ควรเปลี่ยน"
  หลัง build (อย่าใส่ไฟล์ข้อมูล/asset ที่แก้ได้ตามปกติ)

---

## 4. วิธี build แบบกันแกะโค๊ด

```powershell
# ใช้ค่า default API/Registry
pwsh forntend\tool\build_windows_protected.ps1

# กำหนด endpoint เอง
pwsh forntend\tool\build_windows_protected.ps1 `
  -ApiBase "https://host/saccapi/" `
  -RegistryBase "https://host/registryapi/"

# มี bundle อยู่แล้ว ต้องการแค่สร้าง manifest ใหม่
pwsh forntend\tool\build_windows_protected.ps1 -SkipBuild
```

ผลลัพธ์:

- bundle: `forntend\build\windows\x64\runner\Release\`
- manifest: `...\Release\integrity_manifest.json`
- debug symbols: `forntend\build\windows-symbols\` — เก็บไว้ symbolize crash
  **อย่าแจกพร้อมแอป** (มีข้อมูลช่วย deobfuscate)

จากนั้น package ด้วย `release\windows\saccm-setup.iss` ได้ตามเดิม — manifest
อยู่ในโฟลเดอร์ Release จึงถูกรวมเข้า installer อัตโนมัติ

---

## 5. พฤติกรรมเมื่อพบความผิดปกติ

| เหตุการณ์ | ผล |
|---|---|
| ไฟล์ binary ถูกแก้/หาย | หน้าบล็อก "ตรวจพบความผิดปกติของโปรแกรม" |
| พบ debugger ตอนเปิด | หน้าบล็อก "ไม่สามารถเปิดโปรแกรมในโหมดนี้ได้" |
| พบ debugger ระหว่างใช้งาน | สลับเป็นหน้าบล็อกทันที (ตรวจซ้ำทุก ~20 วินาที) |
| แก้ค่า trial/license ในไฟล์ | ค่าที่ลายเซ็นไม่ตรงถูกทิ้ง → กลับไปใช้ค่าที่ถูกต้อง/หมดอายุ |
| debug/profile build | ข้ามการตรวจทั้งหมด (ไม่บล็อก) |

ข้อความทั้งหมดอยู่ใน `lib/constants/transaction_ui_text.dart`
(`guardTamperTitle`, `guardDebuggerTitle` ฯลฯ)

---

## 6. ข้อจำกัดที่ควรรู้

- ผู้โจมตีที่ patch binary แล้ว rebuild manifest เองด้วยคีย์ที่ดึงจาก binary
  ที่ deobfuscate ได้ ยังทำได้ในทางทฤษฎี — นี่คือการกัน casual tampering
- การ sign ไฟล์ติดตั้งด้วย code-signing certificate (Authenticode) เป็นชั้น
  เสริมที่แนะนำเพิ่ม แต่อยู่นอกขอบเขตสคริปต์นี้
- ระบบ trial/license server-anchored (Tier B) ใน `embedded_trial_license.dart`
  ยังทำงานร่วมกับชั้นนี้ตามเดิม
