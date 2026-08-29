# ชุดแจกจ่าย SACCM (Pilot 2 โรงเรียน)

โมเดล: **Server กลาง 2 บริการ** + แอป Windows/Android + **รหัสเปิดใช้งาน**

| บริการ | พอร์ต | หน้าที่ |
|--------|-------|---------|
| **Registry** (`registry-backend`) | 3802 | keygen มาตรฐาน, log เปิดใช้งาน, รายการเครื่อง |
| **แอป (ฝัง)** | — | ทดลองใช้ **90 วัน** บนเครื่อง — ไม่ต้องลงทะเบียนวันแรก |
| **Online API** (`backend`) | 3801 | ข้อมูลการเงิน, sync, login JWT |

```
[Registry :3802]  saccm_registry DB
    │ activate → log
    │ provision ──────────────────┐
    ▼                               ▼
[Online API :3801]  saccm_master + saccm_<school_code>

[โรงเรียน] แอป → Registry (license) + Online API (sync/login)
```

## ขั้นตอนผู้ให้บริการ

### 1) ติดตั้ง Online Backend

```powershell
cd release\backend
.\install.ps1
# ถ้าเพิ่งสร้าง backend\.env ให้แก้ DB / SECRETKEY / INTERNAL_API_SECRET แล้วรัน install.ps1 อีกครั้ง
cd ..\..\backend
npm run migrate
npm start
```

### 2) ติดตั้ง Registry (แยก DB)

```powershell
cd release\registry
.\install.ps1
# ถ้าเพิ่งสร้าง registry-backend\.env ให้แก้ ONLINE_API_BASE, INTERNAL_API_SECRET, LICENSE_ADMIN_SECRET แล้วรัน install.ps1 อีกครั้ง
cd ..\..\registry-backend
npm start
```

### 2.1) ตรวจ production config ก่อนเปิดใช้งานจริง

```powershell
cd release\scripts
.\check-production-config.ps1 `
  -BackendEnv "..\..\backend\.env" `
  -RegistryEnv "..\..\registry-backend\.env"
```

สคริปต์นี้ตรวจเฉพาะความพร้อมของ config โดยไม่แสดงค่า secret ออกมา: `NODE_ENV=production`, secret length, placeholder, CORS, DB user, backend/registry DB separation, และ `INTERNAL_API_SECRET` ที่ต้องตรงกันระหว่างสองบริการ

### 2.2) สำรองฐานข้อมูลก่อน migrate / go-live

```powershell
cd release\scripts
.\backup-mysql.ps1 -Database "saccm_master" -User "saccm_app" -OutDir "..\backups"
.\backup-mysql.ps1 -Database "saccm_registry" -User "saccm_registry" -OutDir "..\backups"
```

สคริปต์ใช้ `mysqldump` พร้อม `--single-transaction`, routines, triggers, events และถาม password แบบ secure prompt; ไฟล์ backup อยู่ใต้ `release\backups` ซึ่งไม่ควร commit เข้า git

### 2.3) รัน staging smoke ก่อน public launch

```powershell
cd backend
$env:E2E_BASE_URL = "https://staging.example.com/saccapi"
$env:DB_NAME = "saccm_staging_e2e"
npm run test:e2e:http:staging
```

คำสั่งนี้ไม่ start server ให้เองและต้องชี้ `E2E_BASE_URL` ไปยัง `/saccapi`; script จะปฏิเสธ URL ที่ไม่ใช่ HTTPS และ DB ที่ชื่อไม่สื่อว่าเป็น test/staging/sandbox เพื่อกันเขียนข้อมูลลง production จริง

### 2.4) One-command go-live preflight

```powershell
cd release\scripts
.\go-live-preflight.ps1 `
  -BackendEnv "..\..\backend\.env" `
  -RegistryEnv "..\..\registry-backend\.env" `
  -RunStagingSmoke `
  -StagingBaseUrl "https://staging.example.com/saccapi" `
  -StagingDbName "saccm_staging_e2e" `
  -CheckDeployedEndpoints `
  -BackendBase "https://api.example.com/saccapi" `
  -RegistryBase "https://api.example.com/registryapi" `
  -Origin "https://app.example.com"
```

สคริปต์นี้รวม production config preflight, backend guard suite (`npm test`), staging smoke แบบ remote endpoint และ deployed endpoint verification เพื่อใช้เป็น gate สุดท้ายก่อน public launch

ถ้าต้องตรวจ endpoint หลัง deploy อย่างเดียว:

```powershell
cd release\scripts
.\check-deployed-endpoints.ps1 `
  -BackendBase "https://api.example.com/saccapi" `
  -RegistryBase "https://api.example.com/registryapi" `
  -Origin "https://app.example.com"
```

endpoint verifier จะตรวจ HTTPS, base path, JSON health response, security headers และ CORS ที่ต้องไม่เป็น wildcard

### 2.5) Deploy บน Linux VPS (production)

บนเซิร์ฟเวอร์ (หลังมี `backend/.env` และ `registry-backend/.env` พร้อม secret จริง):

```bash
cd /var/www/saccm
chmod +x release/scripts/deploy-production-server.sh
PUBLIC_HOST=ktdevelop.com bash release/scripts/deploy-production-server.sh
```

ตั้ง reverse proxy จาก `release/deploy/nginx-saccm.conf.example` (แทน `SERVER_NAME`) แล้ว reload nginx

จากเครื่อง dev (sync โค้ด + deploy ผ่าน SSH):

```powershell
cd release\scripts
.\deploy-production-remote.ps1 -SshTarget "user@ktdevelop.com" -RemoteRepoPath "/var/www/saccm" -PublicHost "ktdevelop.com"
```

สคริปต์จะตั้ง `TRUST_PROXY=true`, `CORS_ORIGIN`, `ONLINE_API_BASE` ให้ตรงโดเมน แล้วรัน migrate + PM2 reload

### 3) สร้างรหัสมาตรฐาน (เมื่อโรงเรียนต้องการลงทะเบียนออนไลน์)

```powershell
cd release\scripts
.\keygen.ps1 -SchoolName "โรงเรียนตัวอย่าง ก."
```

ถ้าเรียกจาก `registry-backend` โดยตรง ใช้ `node scripts/keygen.js --name "ชื่อโรงเรียน"` หรือส่งชื่อโรงเรียนเป็น positional argument ได้ในกรณีที่ npm/Windows shell ตัด `--name` ออก

ทดลองใช้ 90 วัน: เปิดแอปได้เลย — แก้จำนวนวันที่ `forntend/lib/features/license/embedded_trial_license.dart`

บันทึก `SACC-....` ส่งโรงเรียนครั้งเดียว

### 4) Build Client

แอปออกแบบ **offline-first** — เปิดใช้ทดลองบนเครื่องได้ทันทีโดยไม่ต้องมีเน็ต จึง **ไม่จำเป็น** ต้องส่ง `-ApiBase` / `-RegistryBase` ตอน build (ใช้ค่า default ใน `forntend/lib/config.dart`)

```powershell
cd release\scripts
.\build-release.ps1 `
  -SchoolSlug "school-a" `
  -Version "1.0.0" `
  -WindowsOnly
```

ถ้าต้องการ override URL ตอน build (เช่น server คนละโดเมนก่อนแจก):

```powershell
.\build-release.ps1 `
  -SchoolSlug "school-a" `
  -ApiBase "https://your-server.example.com" `
  -RegistryBase "https://your-server.example.com" `
  -Version "1.0.0"
```

สำหรับ build เฉพาะ Windows พร้อม installer แบบเต็ม (wizard ภาษาไทย + ZIP แจกจ่าย):

```powershell
.\build-release.ps1 `
  -SchoolSlug "school-a" `
  -Version "1.0.0" `
  -WindowsOnly `
  -BuildInstaller
```

ผลลัพธ์:
- `release\out\<school>\installer\saccm-<version>-setup.exe` — ตัวติดตั้งหลัก (แนะนำ)
- `release\out\<school>\windows\` — แบบ portable (สำรอง)
- `release\out\saccm-<school>-<version>-windows-setup.zip` — ZIP ส่งโรงเรียน (รวม installer + README + manifest)

ต้องติดตั้ง [Inno Setup 6](https://jrsoftware.org/isinfo.php) ก่อน (`winget install JRSoftware.InnoSetup`)

ตัวติดตั้ง Windows จะ **ตรวจ Microsoft Visual C++ 2015-2022 (x64)** อัตโนมัติ — ถ้ายังไม่มีจะติดตั้งให้ก่อนแอป (ดาวน์โหลด bundle ตอน build ผ่าน `release\windows\ensure-vcredist.ps1`)

ก่อน build Android release ให้ copy `forntend\android\key.properties.example` เป็น `forntend\android\key.properties` แล้วใส่ค่า `storeFile`, `storePassword`, `keyAlias`, `keyPassword` จริง; ไฟล์จริงถูก ignore ไม่เข้า git และ build จะหยุดทันทีถ้าไม่มีไฟล์นี้เพื่อกันการเซ็นด้วย debug key

ก่อน build จริง สคริปต์จะรัน `frontend-release-preflight.ps1` เพื่อเช็ค Android signing (ถ้าไม่ใช่ `-WindowsOnly`), `pubspec.lock`, และ generated Flutter plugin files ว่าไม่มี diff ค้าง; ถ้าส่ง `-ApiBase` / `-RegistryBase` จะตรวจ HTTPS ด้วย

### 4.2) Build Android production (เฉพาะ APK)

ก่อน build ครั้งแรก:

```powershell
copy forntend\android\key.properties.example forntend\android\key.properties
# แก้ storeFile, storePassword, keyAlias, keyPassword
```

Build แจกโรงเรียน (signed release + obfuscate + manifest + ZIP):

```powershell
cd release\scripts
.\build-android-release.ps1 -SchoolSlug "pilot" -Version "1.0.0+1"
```

ตัวเลือก:

```powershell
# APK แยกตาม CPU (ไฟล์เล็กลง — arm64-v8a สำหรับมือถือส่วนใหญ่)
.\build-android-release.ps1 -SchoolSlug "pilot" -SplitPerAbi

# สร้าง AAB เพิ่ม (อัปโหลด Play Console — ไม่ใช่ sideload)
.\build-android-release.ps1 -SchoolSlug "pilot" -BuildAppBundle
```

หรือดับเบิลคลิก `release\android\build-android-release.bat` (default slug `pilot`)

ผลลัพธ์:
- `release\out\<school>\android\saccm-<school>-release.apk`
- `release\out\<school>\manifest.json`, `SHA256SUMS.txt`, `README.txt`
- `release\out\saccm-<school>-<version>-android.zip`
- debug symbols เก็บที่ `release\symbols\<school>\<version>\android\` (ห้ามแจก)

ค่า `-ApiBase` และ `-RegistryBase` เป็น **ทางเลือก** — ไม่ส่งก็ได้ แอปใช้ default จาก `config.dart`; ผู้ดูแลยังแก้ **API URL** ได้จากหน้าตั้งค่าเมื่อพร้อม sync (Registry URL ฝังตอน build/default เท่านั้น)

หลัง build เสร็จ `release\out\<school>\manifest.json` และ `SHA256SUMS.txt` จะถูกสร้างอัตโนมัติ เพื่อใช้ตรวจรายการไฟล์ ขนาด และ SHA256 checksum ก่อนส่งแพ็กเกจให้โรงเรียน

### 4.1) Build Windows Installer (ดับเบิลคลิก)

ติดตั้ง [Inno Setup 6](https://jrsoftware.org/isinfo.php) ก่อน (หรือ `winget install JRSoftware.InnoSetup`)

```
ดับเบิลคลิก: release\windows\build-installer.bat
```

หรือ PowerShell:

```powershell
pwsh release\windows\build-installer.ps1 `
  -ApiBase "https://your-server.example.com" `
  -RegistryBase "https://your-server.example.com"
```

ผลลัพธ์: `release\out\installer\saccm-<version>-setup.exe` — ผู้ใช้ดับเบิลคลิกติดตั้งแบบ wizard ภาษาไทย มีทางลัด Start Menu / Desktop (เลือกได้)

สำหรับ build แจกจ่ายเต็ม (Windows + Android + manifest) พร้อม installer:

```powershell
.\build-release.ps1 ... -BuildInstaller
```

## ขั้นตอนโรงเรียน

| โหมด | พฤติกรรม |
|------|----------|
| **ทดลองใช้บนเครื่อง** | เปิดแอปครั้งแรก → ใช้ได้ 90 วัน ไม่ต้องลงทะเบียน |
| **ลงทะเบียนออนไลน์** | รหัส SACC จาก Registry → sync server ได้ |

## API Registry (`/registryapi/license`)

| Method | Path |
|--------|------|
| POST | `/activate` |
| POST | `/validate` |
| POST | `/status` |
| POST | `/heartbeat` |
| POST | `/admin/generate` |
| GET | `/admin/list` |
| GET | `/admin/issue-logs` |
| GET | `/admin/activation-logs` |
| POST | `/admin/revoke` |

## API Online (เดิม)

| Method | Path |
|--------|------|
| POST | `/saccapi/internal/school/provision` | Registry เรียก (header `X-Internal-Secret`) |
| POST | `/saccapi/login/token` | Login + `schoolCode` |

## ยกเลิกรหัส

```powershell
cd registry-backend
npm run license:revoke -- --school yala-school-a1b2
```

## เอกสารเพิ่มเติม

- `release/docs/KEYGEN-DESIGN.md`
