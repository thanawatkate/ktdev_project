# System Relationships

## Core Relationship Design (Plan B)

- `income_type` เป็นตารางแม่ของหมวดหมู่เงินรับ
- `budget_source_master` เก็บข้อมูลแหล่งเงินหลัก (code, name, type, relation)
- `budget_source_budget` เก็บงบประมาณรายปี และอ้างอิง `budget_source_master`
- `income` ผูกกับ `budget_source_budget` ผ่าน `refBudgetSource`

ความสัมพันธ์นี้ทำให้ flow เป็นลำดับ:

1. สร้างหมวดหมู่เงินรับ (`income_type`)
2. สร้างข้อมูลแหล่งเงินหลัก (`budget_source_master`) และหมวดที่สังกัด
3. สร้างวงเงินรายปี (`budget_source_budget`)
4. บันทึกรับเงิน (`income`) โดยเลือกแหล่งเงินรายปีตามหมวดที่เลือก

## Database Constraints

- เปิดใช้งาน `PRAGMA foreign_keys = ON`
- `budget_source_master.refIncomeType -> income_type.id`
- `budget_source_budget.refBudgetSourceMaster -> budget_source_master.id`
- `income.refBudgetSource -> budget_source_budget.id`

## Migration Notes

- เพิ่ม schema version เป็น `15`
- แปลงตารางเดิม `budget_source` ไปสู่:
  - `budget_source_master` (ระดับแหล่งเงินหลัก)
  - `budget_source_budget` (ระดับปีงบประมาณ)
- คง `id` เดิมไว้ใน `budget_source_budget` เพื่อไม่กระทบ reference ใน `income`

## UI/Behavior Rules

- หน้าแหล่งที่มา (`Budget Source`) ต้องเลือกหมวดรายรับก่อนบันทึก
- หน้าเพิ่มรายการรับเงิน (`Income`) จะแสดงเฉพาะแหล่งเงินรายปีที่อยู่ในหมวดรายรับที่เลือก
- เมื่อแก้ไขข้อมูลรับเงิน ระบบจะพยายาม sync หมวดรายรับจากแหล่งที่มาที่บันทึกไว้

## ตามคู่มือการปฏิบัติงานการเงิน (พ.ศ. 2544)

คู่มือให้บันทึกทะเบียนคุม **แยกตามประเภทของเงิน** (รวมถึงทะเบียนเงินนอกงบประมาณหน้า 40–41 ที่แยกตามประเภท/สายที่กำหนด) — ใน SACCM:

- **หมวดรายรับ** (`income_type`) ควรสอดคล้อง **หนึ่งสายประเภท** ต่อทะเบียนที่คู่มือแยก (เช่นรหัส OB-01..OB-13 กับเงินนอกงบประมาณ)
- **หลายแหล่งงบ** ต่อหมวดรับใช้ได้เมื่อเป็นการแยก **ปีงบประมาณ** (`budget_source_budget` / `budgetsource.fiscal_year`) หรือ **สายโครงการย่อย** ภายใต้ประเภทเดียวกัน — ไม่ใช้หมวดเดียวรวมประเภทเงินที่คู่มือให้แยกทะเบียนคนละชนิด
- **ใบรับเงินแต่ละใบ** อ้าง **หนึ่ง** `refBudgetSource` เสมอ
- **การตรวจอัตโนมัติ:** การบันทึกหมวดรายรับที่ผูกหลายแหล่งจะถูกปฏิเสธ หาก `refmoneygroup` / `budget_type` หรือการผูกหมวดเดิมของแหล่ง (`refincometype` บน MariaDB, `refFundCategory` บน SQLite) ไม่สอดคล้องกันทุกแหล่ง — ดู `backend/src/sacc_incometype/services/incometype.service.js` และ `IncomeTypeProvider.validateLinkedBudgetSourcesForSchoolFinance`
