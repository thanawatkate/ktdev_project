# OBEC Finance Templates (Excel-ready)

ไฟล์ชุดนี้ใช้ประเมินมาตรฐานงานการเงินโรงเรียน สพฐ. และเปิดใน Excel ได้ทันที

1. `01-obec-finance-checklist.csv`
   - Main compliance checklist
   - Enter score in `Score (0-2)` only
   - `Weighted Score`, `Percent`, and `Rating` are auto-calculated

2. `02-corrective-action-plan.csv`
   - Track non-compliance and corrective actions
   - Update `Current Status` and `%` progress regularly

3. `03-executive-summary-report.csv`
   - One-page summary for director/school board
   - Copy final values from checklist and CAP

4. `OBEC-finance-templates.xlsx`
   - หัวตารางภาษาไทยทุกชีต
   - มี dropdown และ validation กันกรอกผิด
   - ล็อกเซลล์สูตร ป้องกันเผลอแก้
   - รหัสป้องกันชีตเริ่มต้น: `1234`
   - มีชีต `Dashboard` และส่วนลงนาม/ความเห็นผู้ตรวจสอบใน `รายงานสรุป`

## การใช้งานด่วน

1. เปิด `OBEC-finance-templates.xlsx`
2. กรอกข้อมูลที่ `หน้าปก`
3. ให้คะแนนที่ `เช็กลิสต์มาตรฐาน` (0-2)
4. กรอกแผนแก้ที่ `แผนแก้ไข (CAP)`
5. ตรวจผลรวมที่ `รายงานสรุป` และ `Dashboard`

## แก้ไขไฟล์ด้วยสคริปต์

- ติดตั้งไลบรารี: `python -m pip install -r requirements.txt`
- สร้างไฟล์ใหม่: `python generate_obec_xlsx.py`

## Scoring standard

- 2 = Pass
- 1 = Needs Improvement
- 0 = Fail

## Suggested Excel formatting

- Format `Percent`, `Completion Rate` as Percentage
- Add conditional colors:
  - Green: >= 80%
  - Yellow: 60%-79%
  - Red: < 60%
