# เฟส 1 — เป้าหมาย 100% (ธุรกรรม · ทะเบียน/ฟอร์ม · Master · รายงาน)

อัปเดต: 2026-05-20  
อ้างอิง: `.cursor/rules/10-saccm-domain-core.mdc`, `TEAM_RULES.md`

เป้าหมายเฟส 1: **ใช้งานจริงที่โรงเรียนได้ครบ 4 หมวดนี้** ก่อนขยาย license/CI/UAT ระดับประเทศ

---

## สถานะรวม (โดยประมาณ)

| หมวด | ก่อนเฟส 1 | หลังงานชุดนี้ | เหลือเพื่อ 100% |
|------|-----------|--------------|----------------|
| Master data / seed | ~70% | ~98% | UAT ข้อมูลจริง, sync จาก server |
| ธุรกรรมหลัก | ~90% | ~97% | expense delete UI, เงินประกัน delete/digest |
| ทะเบียน + ฟอร์ม | ~75% | ~88% | print, สัญญายืม PDF, บก.28 |
| รายงาน UI+API | ~80% | ~96% | CSV ทุกแท็บ, UAT สูตรรวม |

---

## 1. Master data / seed — เกณฑ์ 100%

- [x] `money_group` 5 แถว id 1–5 ชื่อ/sort ตรง `seeds07_moneygroupData.js` (SQLite v16)
- [x] `money_type` ครบ 3 ช่องทางคู่มือ (สด / ฝากธนาคาร+โอน+เช็ค / ส่วนราชการผู้เบิก)
- [x] GOV/NONGOV master ผูก `refmoneygroup` (5 / 2)
- [x] OB-01..OB-13 + OB-07 ชื่อครบ (ยุวกาชาด)
- [x] `expense_type` 00–08
- [x] GUAR-01 / WHT-01 ใน `income_type`
- [x] Backend: ปิด `seeds08` ที่ลบ incometype
- [x] Backend: seed GOV/NONGOV ถ้ายังไม่มี
- [x] NONGOV-OB-01..13 แหล่งงบรายหมวด (backend + SQLite)
- [x] DEP-GUAR / DEP-WHT budget sources บน SQLite
- [x] ตรวจ/เติม `refmoneygroup` บน OB/DEP incometype ฝั่ง MariaDB ผ่าน migration

---

## 2. ธุรกรรมหลัก — เกณฑ์ 100%

| ฟีเจอร์ | สถานะ | งานที่เหลือ |
|---------|--------|-------------|
| รายรับ | ครบเฟส 1 | [x] delete sync รองรับ local/server id และ docno fallback |
| รายจ่าย | ครบเฟส 1 | [x] UI ลบรายการ + คิว sync (ไม่ลบเอกสาร posted) |
| ใบขอเบิก | เกือบครบ | [x] แก้ไข/ลบ offline + PATCH/DELETE |
| อนุมัติ | เกือบครบ | [x] คิว approve/reject offline |
| ยืม/คืน | เกือบครบ | [x] แก้ DELETE URL `/loan/:id`, `/repayloan/:id` |
| จ่ายเช็ค | เกือบครบ | [x] คิว `markCleared` เมื่อออฟไลน์ |
| เงินประกัน | ครบเฟส 1 | [x] ลบ offline, digest sync, ใช้ `settle` ให้ชัด |

---

## 3. ทะเบียนคุม + ฟอร์ม — เกณฑ์ 100%

### ทะเบียน 10 แท็บ

| # | แท็บ | โหลดข้อมูล | CRUD | Export |
|---|------|------------|------|--------|
| 1 | นอกงบ 13 หมวด | SQLite | อ่าน→ลิงก์รับ/จ่าย | CSV |
| 2 | หลักฐานขอเบิก | API→local fallback | อ่าน→ใบขอเบิก | [x] CSV |
| 3 | ใบสำคัญคู่จ่าย | API→local fallback | อ่าน→รายจ่าย | [x] CSV + PDF บค. |
| 4 | จ่ายเช็ค | API+local | ตัดบัญชี | [x] CSV |
| 5 | สัญญายืม | API→local fallback | อ่าน→ยืม/คืน | [x] CSV + PDF สัญญา |
| 6 | ใบเสร็จ | API→SQLite fallback | issue/PATCH/DELETE | [x] CSV |
| 7 | ประกัน/ภาษี | **ครบ** | **ครบ** | CSV/PDF |
| 8–10 | ธนาคาร/สปช./แผ่นดิน | API→local fallback | อ่าน→ธุรกรรม | [x] CSV |

**รูปแบบเป้าหมาย:** Repository เดียว — `remote → upsert SQLite → แสดง local` (เหมือนแท็บ 7)

### ฟอร์ม PDF

- [x] บก.111, บค., ใบแนบ, ทะเบียนประกัน
- [x] บก.28 ระบุแบบฟอร์มใน PDF แล้ว (ต้อง UAT layout ทางการกับเอกสารจริง)
- [x] สัญญายืมเงิน `POST /forms/loan-contract`
- [x] ดาวน์โหลด PDF บนเว็บ
- [x] ส่งแถว local เข้า deposit-register เมื่อออฟไลน์

---

## 4. รายงาน (UI + API) — เกณฑ์ 100%

| แท็บ / API | API | UI | Offline compute |
|------------|-----|----|-----------------|
| ภาพรวม–งบคงเหลือ (0–4) | มี | มี | [x] local bundle fallback |
| รับ-จ่ายประจำปี (5) | มี | มี | [x] local rollup พื้นฐาน |
| เงินคงเหลือประจำวัน (6) | มี | มี | [x] `DailyBalanceLocalComputer` |
| สรุปเงินสดรายวัน (7) | มี | มี | [x] มีอยู่แล้ว |
| เทียบยอดธนาคาร (8) | มี | มี | [x] local movement |
| ปิดวัน (9) | ใช้ daily-balance | มี | ขึ้นกับ (6) |
| เงินยืมค้าง (10) | — | SQLite | ครบ |
| เช็คค้าง (11) | มี | มี | [x] fallback local |
| `GET /reports/daily` | มี | ไม่มี | รวมในแท็บ 6/7 หรือเพิ่มแท็บ |

---

## ลำดับทำงานแนะนำ (ทีม)

1. **Master v16** — รันแอปให้ migrate SQLite; ตรวจหน้าแหล่งเงิน/หมวดรับ  
2. **Sync bugs** — loan/repay delete, income delete id  
3. **รายงาน offline** — daily balance (ทำแล้ว), ต่อ bank recon + bundle  
4. **ทะเบียน** — `RegisterRepository` แบบ deposit สำหรับแท็บ 1–6, 8–10  
5. **ฟอร์ม** — บก.28 + สัญญายืม  
6. **UAT checklist** — ไฟล์แยกต่อแท็บ/ธุรกรรมกับข้อมูลโรงเรียนจริง  

---

## ไฟล์ที่แตะในรอบนี้

- `forntend/lib/core/local_data_source/app_database.dart` — db v16, seed 5 money groups
- `forntend/lib/features/reports/data/daily_balance_local_computer.dart` — คำนวณหน้า 34 จาก SQLite
- `forntend/lib/features/reports/data/repositories/reports_repository_offline.dart`
- `forntend/lib/features/reports/presentation/widgets/daily_balance_tab.dart`
- `forntend/lib/features/loan/data/repositories/*_repository_offline.dart`
- `backend/data/seeds/seeds08_incometypeData.js`
- `backend/migrations/20260520000001_seed_gov_nongov_budgetsource.js`
