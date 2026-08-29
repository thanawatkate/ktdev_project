# Terminology Standard

## Goal

ให้ทุกหน้าจอใช้คำเดียวกัน เพื่อลดความสับสนระหว่างการบันทึกรายการรับเงิน การตั้งค่า และรายงาน

## Standard Terms

- `หมวดรายรับ`  
  ใช้กับข้อมูลประเภทของรายการรับเงิน เช่น ค่าบำรุง ดอกเบี้ย เงินอุดหนุน

- `แหล่งเงิน`  
  ใช้กับที่มาของงบ/เงิน เช่น งบประมาณแผ่นดิน นอกงบประมาณ

- `วิธีรับเงิน`  
  ใช้กับช่องทางหรือรูปแบบการรับเงิน เช่น เงินสด เงินโอน เช็ค

## Mapping (Old -> New)

- `หมวดหมู่รายรับ` -> `หมวดรายรับ`
- `กลุ่มเงิน` -> `แหล่งเงิน`
- `ประเภทเงิน` -> `วิธีรับเงิน`

## UI Label Keys (Current)

- `TransactionUiText.incomeType` = `หมวดรายรับ`
- `TransactionUiText.sourceGroup` = `แหล่งเงิน`
- `TransactionUiText.receiveMethod` = `วิธีรับเงิน`
- `TransactionUiText.incomeTypeTitle` = `หมวดรายรับ`
- `TransactionUiText.incomeTypeManage` = `กำหนดหมวดรายรับ พร้อมเลือกแหล่งเงินและบัญชีธนาคารที่เกี่ยวข้อง`

## Database Meaning

- `income_type` = หมวดรายรับ
- `budget_source_master` / `budget_source_budget` = แหล่งเงิน
- `money_type` = วิธีรับเงิน

## Notes for Developers

- หากเพิ่มหน้าจอใหม่ ให้ยึดคำมาตรฐานชุดนี้
- ชื่อ endpoint/ชื่อคอลัมน์เดิมที่เป็น legacy สามารถคงไว้ได้ แต่ label ใน UI ต้องใช้คำใหม่
