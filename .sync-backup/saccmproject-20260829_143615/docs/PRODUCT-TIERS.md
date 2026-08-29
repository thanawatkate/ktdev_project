# แพ็กเกจการขาย SACCM

| # | แพ็กเกจ | ที่เก็บ | ลงทะเบียน |
|---|---------|---------|-----------|
| 1 | **ทดลองใช้** | `embedded_trial_license.dart` → `kEmbeddedTrialDays` | ไม่ต้อง |
| 2 | **ออฟไลน์** | Registry `license_kind=offline` | รหัส SACC + อินเทอร์เน็ตครั้งแรก |
| 3 | **ออนไลน์+ออฟไลน์** | Registry `license_kind=online` | รหัส SACC + provision server |

## Keygen (ผู้ให้บริการ)

```powershell
# ออฟไลน์ (default)
.\release\scripts\keygen.ps1 -SchoolName "โรงเรียน ก."

# ออนไลน์+ซิงก์
.\release\scripts\keygen.ps1 -SchoolName "โรงเรียน ข." -Tier online
```

## แอป

- ตั้งค่า → **แผนการใช้งาน / แพ็กเกจ** (`/product-plan`)
- ลงทะเบียน — ต้องมีเน็ตครั้งแรก (ตรวจ Registry) · แพ็กเกจออฟไลน์ใช้ต่อได้โดยไม่ต้องมีเน็ต
- หมดทดลองใช้ / หมดอายุรหัส — บล็อกหน้าจอ พร้อมลิงก์ไปแผนแพ็กเกจ

## ตรวจอายุรหัส

| แพ็กเกจ | ตรวจเมื่อ |
|---------|-----------|
| ทดลองใช้ | วันเริ่มในเครื่อง |
| ออฟไลน์ | `expires_at` ที่บันทึกตอน activate |
| ออนไลน์ | `expires_at` + ตรวจ Registry เมื่อมีเน็ต |

เอกสารฉบับเต็ม (HTML): [`docs/registry-and-license.html`](../registry-and-license.html) · กฎทีม: `TEAM_RULES.md` §14
