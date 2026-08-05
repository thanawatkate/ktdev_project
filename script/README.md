# scripts/sync-submodules.sh

ซิงค์ git submodules ของโปรเจกต์ให้ตรงกับ `.gitmodules` — เพิ่ม submodule ใหม่, ลบ submodule/โฟลเดอร์ที่ไม่ได้ประกาศไว้แล้ว, และดึงโค้ดล่าสุดโดยไม่ทับการแก้ไขที่ยังไม่ commit

## วิธีใช้งาน

```bash
./scripts/sync-submodules.sh
```

รันจากที่ไหนก็ได้ในโปรเจกต์ สคริปจะ `cd` ไปที่ root ของ repo ให้อัตโนมัติ

## สิ่งที่สคริปทำ (ตามลำดับ)

1. **อ่าน `.gitmodules`** — เก็บรายชื่อ submodule ทั้งหมด (name, path, url)

2. **ลบโฟลเดอร์ที่ไม่ใช่ submodule แล้ว**
   ตรวจทุกโฟลเดอร์ใน root (ยกเว้น `scripts`, `docs`, `deploy`) ว่า:
   - ไม่มีอยู่ใน `.gitmodules` **และ**
   - เป็น git repo/submodule เก่า (มี `.git` ไฟล์หรือโฟลเดอร์ หรือมี gitlink `160000` ค้างอยู่ใน index)

   ถ้าตรงเงื่อนไข จะ `deinit` + `git rm --cached` + ลบโฟลเดอร์ทิ้ง แล้ว commit การลบให้อัตโนมัติ (commit message: `chore: remove stale submodule gitlinks`)

3. **`git submodule sync --recursive`** — อัปเดต remote URL ใน `.git/config` ให้ตรงกับ `.gitmodules` (กรณีเปลี่ยน URL)

4. **เพิ่ม submodule ใหม่ที่ยังไม่ได้ register**
   ถ้า path ใน `.gitmodules` ยังไม่มี gitlink ในดัชนี git (เช่น เพิ่ง `.gitmodules` เพิ่ม entry เข้ามาใหม่ หรือเคยถูกลบไปก่อนหน้านี้) จะรัน `git submodule add` ให้อัตโนมัติ

5. **`git submodule update --init --recursive`** — init submodule ที่ยังไม่เคย clone

6. **Pull โค้ดล่าสุดของแต่ละ submodule** โดยไม่ทับ local changes:
   - ถ้ามีการแก้ไขที่ยังไม่ commit จะ `git stash` ก่อน
   - `git fetch` + `git checkout` default branch (อ่านจาก `origin/HEAD`, fallback เป็น `main`)
   - `git pull --rebase`
   - `git stash pop` คืนค่าการแก้ไขกลับมา (ถ้า pop ไม่สำเร็จจะแจ้งเตือนให้แก้ conflict เอง ไม่ fail เงียบ)

7. **แสดงสถานะ submodule ทั้งหมด** (`git submodule status --recursive`)

## ข้อควรระวัง

- ลบเฉพาะไฟล์/โฟลเดอร์ใน **local repo นี้เท่านั้น** ไม่กระทบ remote repository ต้นทางของ submodule
- ถ้า `git stash pop` เกิด conflict สคริปจะไม่ resolve ให้ ต้องเข้าไปแก้ใน submodule นั้นด้วยตนเอง
- โฟลเดอร์ `scripts`, `docs`, `deploy` ถูก exclude จากการตรวจสอบ/ลบเสมอ
