# เฟส 2 — ความพร้อมใช้งานจริงระดับโรงเรียนหลายเครื่อง

อัปเดต: 2026-05-20  
ต่อจาก: `docs/PHASE1-COMPLETION.md`

เป้าหมายเฟส 2: ทำให้ระบบที่ใช้งานธุรกรรม/ทะเบียน/รายงานได้แล้วในเฟส 1 พร้อมสำหรับการใช้จริงต่อเนื่องหลายวัน หลายเครื่อง และตรวจสอบย้อนหลังได้

---

## สถานะรวม

| หมวด | เป้าหมาย | สถานะ |
|------|----------|-------|
| Daily closing | ปิดวัน local-first + snapshot + sync | ทำแล้วรอ UAT |
| Bank reconciliation | บันทึก reason code + sync | ทำแล้วรอ UAT |
| UAT ข้อมูลจริง | checklist รายธุรกรรม/รายงาน | มี checklist แล้ว รอรันจริง |
| CI / regression | analyzer + backend syntax + test ชุดหลัก | มี workflow แล้ว |
| License / multi-device sync | ยืนยัน token refresh + digest/full mirror | ยังต้อง UAT |

---

## 1. Daily Closing / Reconciliation

- [x] ปิดวันจากข้อมูล local ได้ แม้ server ใช้งานไม่ได้
- [x] เก็บ `daily_closing.snapshot_json` เป็น snapshot ณ วันที่ปิด
- [x] คิว sync `close-day` ขึ้น server เมื่อออนไลน์
- [x] mark `daily_closing.synced = 1` เมื่อ sync สำเร็จ
- [x] ห้ามปิดวันซ้ำทั้ง local และ server
- [x] บันทึกเหตุผลงบเทียบยอดธนาคารแบบ offline queue

---

## 2. UAT ข้อมูลจริง

- Checklist แยก: `docs/PHASE2-UAT-CHECKLIST.md`

- [ ] รับเงินงบประมาณ / รายได้แผ่นดิน / นอกงบประมาณครบ 13 หมวด
- [ ] จ่ายเงินสด / ธนาคาร / ส่วนราชการผู้เบิก แล้วรายงานเงินคงเหลือตรง
- [ ] ยืมเงิน → คืนเงินยืม → รายงานเงินยืมค้างตรง
- [ ] เงินประกัน/ภาษีหัก ณ ที่จ่าย → settle → ทะเบียนและรายงานตรง
- [ ] ใบเสร็จรับเงิน: issue / void / ช่วงเล่ม ถูกต้อง
- [ ] ปิดวันสิ้นวัน และเทียบยอดกับรายงานหน้า 34

---

## 3. CI / Regression

- [x] เพิ่ม workflow `.github/workflows/phase2-regression.yml`
- [x] `flutter analyze`
- [x] unit tests ที่แตะ repository sync/offline
- [x] `node --check` หรือ test backend สำหรับ services/routes สำคัญ
- [ ] regression mapping OB-01..OB-13 / money_group / pocket classifier

---

## 4. License / Multi-Device Sync

- [ ] ยืนยัน endpoint token refresh กับ registry จริง
- [ ] sync digest ครบตารางสำคัญหลังเพิ่ม `deposit_guarantee`
- [ ] full mirror ไม่ทับ local pending writes
- [ ] ทดสอบเครื่อง A offline write → เครื่อง B sync อ่านข้อมูลหลัง server รับ

