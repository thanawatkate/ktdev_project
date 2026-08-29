# กฎและแนวปฏิบัติของทีม — SACCM Project

> อัปเดตล่าสุด: 2026-06-23 (เพิ่ม §14 Registry/License + เอกสาร HTML)  
> ใช้กับทุกคนในทีมและกับ AI agent ที่ทำงานในโปรเจกต์นี้
> ไฟล์นี้เป็นกฎหลักของโปรเจกต์ (canonical rule file) สำหรับทั้งทีม, Cursor และ GitHub Copilot

---

## 0. แผนที่กฎในไฟล์นี้

ไฟล์นี้เป็น canonical rule file เดียวของทีม แต่ให้แยก “ประเภทกฎ” ให้ชัดเมื่อใช้งาน:

- **กฎออกแบบ UI / Flutter layout** อยู่ใน `§4.3` ถึง `§4.6` โดยเฉพาะ `§4.3.1` ซึ่งเป็น canonical ของหน้าฟอร์ม/รายละเอียด และ `§4.3.4` สำหรับมาตรฐาน popup/form sheet
- **คู่มือผู้ใช้ในแอป** อยู่ใน `§6` ใช้สำหรับเนื้อหา help/usage flow ที่ผู้ใช้เปิดอ่าน ไม่ใช่มาตรฐาน layout
- **คู่มือการเงิน / กฎโดเมนบัญชี** อยู่ใน `§11` ถึง `§13` ใช้สำหรับ business rule, mapping, workflow, checklist และ PR template ของงานการเงิน
- **Registry, License และการแจกจ่าย** อยู่ใน `§14` และเอกสาร HTML `docs/registry-and-license.html` — ใช้เมื่อแก้ `registry-backend`, activation, trial, `SACC_REGISTRY_BASE`, master sync หลัง activate
- ห้ามเอาข้อความอ้างอิงคู่มือ เช่น `คู่มือหน้า ...` หรือเหตุผลเชิงเอกสาร ไปปนใน label/help text ของ UI ผู้ใช้โดยตรง ให้เก็บไว้ใน docs, rule layer, usage guide หรือ PR context แทน

---

## 1. โครงสร้างโปรเจกต์ (ภาพรวม)

```
saccmproject/
├── backend/           # Node.js + Express + Knex (MariaDB/MySQL) — Online API
├── registry-backend/  # Registry license/keygen/activate (DB แยก saccm_registry)
├── forntend/          # Flutter (local-first SQLite + background sync)
├── release/           # สคริปต์ build แจกจ่าย, keygen, install
├── docs/              # เอกสารอ้างอิง (รวม registry-and-license.html)
└── TEAM_RULES.md      ← ไฟล์นี้ (canonical rule file ทั้งโปรเจกต์)
```

> ชื่อโฟลเดอร์ `forntend/` เป็นชื่อที่ใช้มาตั้งแต่ต้นโปรเจกต์ — **ห้ามเปลี่ยนชื่อ** เพราะจะกระทบ path ทุกอย่าง

---

## 2. Git & Branch

| กฎ | รายละเอียด |
|---|---|
| Branch หลัก | `main` — ต้องผ่าน review ก่อน merge เสมอ |
| ตั้งชื่อ branch | `feat/<ชื่อสั้น>`, `fix/<ชื่อสั้น>`, `chore/<ชื่อสั้น>` |
| Commit message | ภาษาไทยหรืออังกฤษก็ได้ แต่ต้องระบุว่าแตะอะไร เช่น `feat: เพิ่มหน้าประเภทรายรับ`, `fix: แก้ FK CASCADE ใน loan_sub` |
| ห้าม force push | ยกเว้น branch ส่วนตัว ก่อนเปิด PR |
| PR ต้องมี | คำอธิบายสั้นว่าเปลี่ยนอะไร + แตะ DB หรือ UI ผู้ใช้หรือไม่ |

---

## 3. กฎ Backend (Node.js / Knex)

### 3.0 โครงสร้างโฟลเดอร์ Backend

```
backend/
├── src/
│   ├── configs/      # Database และ configuration
│   ├── routes/       # API routes (เรียก service/controller ของแต่ละ feature module)
│   ├── sacc_*/       # Feature modules (controller + service ต่อ domain)
│   └── utils/        # Utility functions
├── migrations/       # Knex migrations
├── data/seeds/       # seed data (master/lookup)
└── index.js          # Entry point
```

### 3.1 Migration

- **ทุกการเปลี่ยน schema** ต้องสร้าง migration file ใหม่ใน `backend/migrations/` ด้วยคำสั่ง `knex migrate:make`
- ตั้งชื่อไฟล์: `YYYYMMDDHHMMSS_<verb>_<table>.js` เช่น `20260505000001_add_status_to_income.js`
- Migration ต้องรัน `npm run migrate` ได้สำเร็จโดยไม่ error ก่อน push
- ห้าม edit migration เก่าที่ commit แล้ว — ให้สร้าง migration ใหม่แทนเสมอ

### 3.2 API Routes

- จัดไว้ใน `backend/src/routes/` และเรียกผ่าน feature module `backend/src/sacc_*/`
- ทุก endpoint ที่แก้/เพิ่มข้อมูลต้องตรวจ JWT token ก่อน
- ห้ามวาง business logic ใน route handler โดยตรง — ให้แยกออกไปเป็น service/controller

### 3.3 Knex / Query

- ใช้ parameterized query เสมอ — **ห้าม string interpolation ใน SQL**
- Transaction (`knex.transaction`) ทุกครั้งที่เขียนหลายตารางพร้อมกัน

---

## 4. กฎ Frontend (Flutter)

อ้างอิงจาก `.cursor/rules/` — ให้ยึดตามทุก rule ที่มี `alwaysApply: true`

### 4.1 สถาปัตยกรรม (Clean Architecture)

```
lib/
├── core/               # Core functionality (ใช้ร่วมทุก feature)
│   ├── error/          # Error / Failure types
│   ├── network/        # Network utilities (Dio client, interceptor)
│   ├── usecases/       # Base UseCase contract
│   ├── utils/          # Utilities ทั่วไป
│   └── di/             # Dependency injection (service_locator.dart)
├── features/
│   └── <feature>/
│       ├── data/             # Data layer
│       │   ├── datasources/  # remote (Dio) + local (SQLite DAO)
│       │   ├── models/       # DTO ที่แปลงไป-กลับกับ entity
│       │   └── repositories/ # Repository implementations
│       ├── domain/           # Domain layer (business core)
│       │   ├── entities/     # Business entities (ไม่ขึ้นกับ framework)
│       │   ├── repositories/ # Repository interface (contract)
│       │   └── usecases/     # Use cases (one action per class)
│       └── presentation/     # Presentation layer
│           ├── bloc/         # State management (Provider/Bloc/Cubit)
│           ├── pages/        # UI screens
│           └── widgets/      # Reusable UI widgets ของ feature นี้
└── main.dart
```

**หน้าที่ของแต่ละ layer**

| Layer | บทบาท |
|---|---|
| Presentation | UI + state — เรียกเฉพาะ Use Case / Repository interface เท่านั้น |
| Domain | Business rule ของ feature — เป็น layer ที่ทุกอย่างพึ่งพาแต่ตัวมันไม่ขึ้นกับใคร |
| Data | ทำตามสัญญา (interface) ของ domain โดยต่อ datasource จริง (Dio/SQLite) |

**กฎเหล็ก**

- ห้ามเรียก `Dio` / HTTP โดยตรงจาก `*_page.dart` หรือ widget — ต้องผ่าน Use Case → Repository → DataSource
- **UI อ่าน SQLite ก่อนเสมอ** — remote เป็น background sync เท่านั้น (ดู §4.2)
- Domain layer **ห้าม import** ของ Flutter framework หรือ package ภายนอก (ยกเว้น util ของ Dart) — ทำให้ทดสอบและสลับ data source ได้

#### 4.1.1 การเพิ่ม Feature ใหม่

โครงขั้นต่ำตอนสร้าง feature ใหม่:

```
features/
└── new_feature/
    ├── data/
    │   ├── datasources/
    │   ├── models/
    │   └── repositories/
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    └── presentation/
        ├── bloc/
        ├── pages/
        └── widgets/
```

#### 4.1.2 Register Dependencies (DI)

เพิ่มที่ `forntend/lib/core/di/service_locator.dart`:

```dart
_services[NewRepository] = NewRepositoryImpl(
  remoteDataSource: get<NewRemoteDataSource>(),
  localDataSource: get<NewLocalDataSource>(),
);
_services[GetNewThing] = GetNewThing(get<NewRepository>());
```

#### 4.1.3 ตัวอย่าง Use Case

```dart
class GetSomething implements UseCase<Something, NoParams> {
  final SomethingRepository repository;

  GetSomething(this.repository);

  @override
  Future<Either<Failure, Something>> call(NoParams params) async {
    return await repository.getSomething();
  }
}
```

#### 4.1.4 สถานะการ Migrate ไป Clean Architecture

โปรเจกต์ยังอยู่ระหว่างทยอย migrate จาก legacy code เป็น Clean Architecture:

- Auth: ใช้ Clean Architecture เต็มรูปแบบแล้ว
- Feature legacy ที่ยังไม่ migrate จะอยู่ในโฟลเดอร์ที่ขึ้นต้นด้วย `_` (เช่น `_*`) — เมื่อแก้บ่อย ๆ ให้พิจารณา migrate เลย
- Feature ใหม่ทุก feature **ต้อง** ใช้ Clean Architecture ตามโครงที่ระบุข้างต้นเสมอ ห้ามวางในรูปแบบ legacy

### 4.2 Local-first (SQLite)

- รายการ, dropdown, lookup, dashboard, register, report, detail page และข้อมูลธุรกิจทุกอย่างที่มีตารางใน `app_database.dart` → อ่านผ่าน **DAO/Repository local เท่านั้น** ใน read path ของ UI
- ห้ามให้ UI หรือ Repository ที่ถูก UI เรียกเพื่อแสดงผล `await` network/remote แล้วนำผลนั้นมาแสดงโดยตรง; ถ้าต้องเติมข้อมูลจาก server ให้ทำเป็น background sync ลง SQLite ก่อน แล้ว UI ค่อยอ่าน SQLite รอบถัดไป
- Server มีหน้าที่เป็นปลายทางเก็บข้อมูล/สำรอง/ซิงก์เท่านั้น ไม่ใช่ source of truth สำหรับการอ่านในแอป runtime; source of truth ฝั่งแอปคือ SQLite
- Sync ขึ้น/ดึงจาก server ต้องใช้ `unawaited(...)`, worker, หรือ sync service และต้องไม่บล็อกหน้าจอเพื่อรอ remote
- การ enqueue sync, auto-sync, manual sync, API health check, background pull/push และ UI ที่เกี่ยวกับ server sync ทำได้เฉพาะแพ็กเกจ **ออนไลน์+ออฟไลน์** ตาม §4.2.3 เท่านั้น (`LicenseMode.canSyncOnline()` / `SyncUiRules.canShowServerSyncUi(context)`)
- ห้ามใช้การมี server JWT หรือ token ที่ไม่ใช่ `local_` เป็นเงื่อนไขแทน §4.2.3 เพราะเครื่องที่ activate online แล้วอาจใช้ local token ระหว่าง offline ได้
- ทุก feature ใหม่ที่มีตาราง: เพิ่ม **localdb ก่อน** → Repository อ่าน local เท่านั้น → ค่อยเพิ่ม sync/background mirror ที่ถูก gate ด้วย §4.2.3
- ข้อยกเว้น remote read ที่ยอมได้: activation/license registry, login/token refresh, admin-only license console, และ endpoint ที่ใช้เพื่อสร้างไฟล์/ผลลัพธ์ที่ไม่มีตาราง local รองรับ; ห้ามใช้ข้อยกเว้นนี้กับรายการธุรกิจที่ mirror ใน SQLite แล้ว

#### 4.2.1 กฎการบันทึกข้อมูลธุรกรรม: Auto-save vs Save จริง

ใช้กับหน้าฟอร์มธุรกรรมที่มี auto-save เช่น รายรับ รายจ่าย ใบขอเบิก และฟอร์มเอกสารการเงินที่มีลักษณะเดียวกัน:

- **Auto-save = ร่างชั่วคราวของระบบ** เพื่อกันข้อมูลหายระหว่างกรอกเท่านั้น ไม่ใช่ action ที่ผู้ใช้ต้องเลือกเอง
- หน้าฟอร์มเพิ่มรายการ **ห้ามให้ผู้ใช้เลือกสถานะเอกสาร** (`draft` / `approved` / `posted`) ถ้ามี auto-save อยู่แล้ว เพราะทำให้สับสนระหว่าง “ร่างอัตโนมัติ” กับ “สถานะงานจริง”
- ปุ่มหลัก เช่น `บันทึก`, `บันทึกรายรับ`, `บันทึกและพิมพ์` ต้องหมายถึง **บันทึกรายการจริง** และส่ง `doc_status = posted` เว้นแต่ feature นั้นมี flow อนุมัติแยกที่ออกแบบไว้ชัดเจน
- สถานะเอกสารให้แสดงเป็น read-only badge/text ในหน้ารายการหรือหน้าแก้ไข/รายละเอียดเท่านั้น หากต้องเปลี่ยนสถานะ ให้ทำผ่าน flow เฉพาะ เช่น ส่งขออนุมัติ อนุมัติ ลงบัญชี หรือยกเลิก
- ข้อความ auto-save ควรเป็นข้อความช่วยเหลือเล็ก ๆ เช่น `บันทึกร่างอัตโนมัติแล้ว` และไม่ควรอยู่ในตำแหน่งเดียวกับปุ่มบันทึกจริงจนทำให้ผู้ใช้เข้าใจว่าเป็นทางเลือกการบันทึก

#### 4.2.2 ห้าม `rawQuery` กระจาย — ใช้เมธอดบน LocalDataSource (helper) แทน

- **Presentation** (`forntend/lib/**/presentation/**` — หน้า, widget, provider ที่เรียกจาก UI โดยตรง): **ห้าม** เรียก `Database.rawQuery` / `txn.rawQuery` / `Batch.rawQuery` — ต้องอ่านผ่านเมธอดบนคลาส **LocalDataSource** (เช่น `*LocalDataSource` ใน `forntend/lib/core/local_data_source/` หรือ `forntend/lib/features/<feature>/data/datasources/`) ที่รวม SQL ไว้ในที่เดียวและตั้งชื่อเมธอดให้สื่อความหมาย (เช่น `queryExpenseTypesWithDefaultBudgetJoin`)
- **Repository / offline repository**: ห้ามพ่วง `db.rawQuery` จากนอก datasource — ให้เพิ่มเมธอดบน LocalDataSource แล้ว repository เรียกเมธอดนั้นแทน (รวม SQL ไว้ชั้น datasource เท่านั้น)
- **ข้อยกเว้น**: `app_database.dart` (migration, `PRAGMA`, seed, integrity check, introspection ระหว่างอัปเกรด schema) และเครื่องมือ dev ที่ไม่ใช่ runtime ของแอป — ไม่นับเป็น “feature query” ตามกฎข้อนี้
- โค้ดเก่าที่ยังมี `rawQuery` นอก datasource — เมื่อแตะไฟล์นั้นให้ย้ายเข้าเมธอด datasource ตามโอกาส (ไม่บังคับ refactor ทั้ง repo ในครั้งเดียว)

#### 4.2.3 กฎการแสดงสถานะ Sync / รอส่งเซิร์ฟเวอร์

- ป้ายหรือปุ่มที่สื่อถึงการส่งข้อมูลขึ้น server กลาง เช่น `รอส่งเซิร์ฟเวอร์`, `ซิงก์แล้ว`, ปุ่ม manual sync และตัวนับ pending queue ต้องแสดงเฉพาะเครื่องที่ผ่านการ activate แพ็กเกจ **ออนไลน์+ออฟไลน์** แล้ว (`LicenseMode.canSyncOnline()` / `SimpleAuthProvider.canShowServerSyncUi == true`) เท่านั้น
- ห้ามใช้การมี server JWT ใน session ปัจจุบันเป็นเงื่อนไขแสดง UI กลุ่มนี้ เพราะเครื่องที่ activate online แล้วอาจกำลังใช้ local token ระหว่างออฟไลน์ได้
- ระบบ trial, local-only หรือแพ็กเกจ offline-only ห้ามแสดงข้อความ/ปุ่มกลุ่มนี้ เพราะไม่มี flow ส่งข้อมูลขึ้น server ให้ผู้ใช้รอ
- ระบบ trial และแพ็กเกจ offline-only ต้องแสดงสถานะ `ทำงาน Offline` เสมอ และห้ามตรวจ backend/API health check, ห้าม enqueue sync queue ใหม่, ห้าม manual sync และห้าม auto-sync background ไป server
- เฉพาะแพ็กเกจ **ออนไลน์+ออฟไลน์** เท่านั้นที่ตรวจ API, แสดงปุ่ม sync/manual pending queue และทำ background auto-sync เมื่อเชื่อมต่อ API ได้
- UI ห้ามสร้าง sync badge เองในหน้า feature ให้ใช้ `ServerSyncStatusBadge` หรือ `SyncUiRules.canShowServerSyncUi(context)` จาก `forntend/lib/widgets/sync_status_badge.dart` เพื่อให้กฎเดียวกันใช้กับทุกส่วน

#### 4.2.4 Flutter Web compatibility ของ local-first

- Flutter Web ต้องยังคง local-first: ใช้ `sqflite_common_ffi_web`/IndexedDB เป็น local database และ UI ต้องอ่าน/เขียน local repository ก่อนตาม §4.2
- ไฟล์ที่อยู่ใน web build graph ห้าม `import 'dart:io'` โดยตรง แม้จะมี `kIsWeb` guard อยู่ใน runtime ก็ตาม เพราะ Web compiler จะ fail ตั้งแต่ compile time
- โค้ดที่ต้องใช้ไฟล์, `Platform`, `Process`, path ของ OS, backup/restore ไฟล์ SQLite หรือเปิดโฟลเดอร์ ต้องอยู่หลัง conditional import/export เท่านั้น เช่น helper ใน `core/platform/*` หรือไฟล์ suffix `_io.dart` ที่ export ผ่าน stub สำหรับ Web
- ถ้าต้องรู้ platform ในโค้ดที่ compile ได้ทุก target ให้ใช้ `kIsWeb` + `defaultTargetPlatform` หรือ helper กลาง เช่น `runtimePlatformId`/`isDesktopRuntime` แทน `dart:io Platform`
- Feature ที่ Web ยังไม่รองรับ เช่น backup/restore ไฟล์ `saccm.db` ให้ degrade อย่างชัดเจน เช่น copy CSV ลง clipboard หรือแสดงข้อความไม่รองรับ ห้ามปล่อยให้ compile web พัง
- เมื่อแตะไฟล์ platform-specific หรือเพิ่ม dependency ฝั่ง local-first ให้รันอย่างน้อย `flutter analyze` และถ้าเป็นไปได้รัน `flutter build web` เพื่อตรวจ compile path ของ Web

### 4.3 UI Components

ส่วนนี้เป็น **กฎออกแบบ UI และ component standard** เท่านั้น ไม่ใช่คู่มือผู้ใช้และไม่ใช่กฎโดเมนการเงิน; คู่มือผู้ใช้ให้อ้าง `§6` และกฎที่อิงคู่มือการเงินให้อ้าง `§11`

รายละเอียด **เลย์เอาต์หน้าฟอร์ม / การ์ด / responsive** ของโปรเจกต์อยู่ที่ **§4.3.1** — ตารางด้านล่างเป็น mapping widget มาตรฐาน

| งาน | ใช้ Widget | หมายเหตุ |
|---|---|---|
| Input ข้อความ/ตัวเลข/วันที่/ค้นหา | `AppInput` (จาก `widgets/widgets.dart`) | Pill-shaped pill เสมอ (borderRadius 50) |
| Input วันที่อื่น | `AppDateInput` (จาก `widgets/widgets.dart`) | Pill-shaped, รองรับ Thai Buddhist + locale |
| Lookup / dropdown ฟอร์มที่มาจาก master data หรือรายการธุรกิจ **มากกว่า 6 รายการ** | `AppLookupPickerField` | แสดงเป็น read-only `AppInput` แล้วเปิด bottom sheet ค้นหา/เลือก |
| Lookup / dropdown ที่มี **6 รายการหรือน้อยกว่า** หรือ enum/filter สั้น ๆ | `AppDropdownField` | ใช้เมื่อรายการสั้น เลือกง่าย และไม่ต้องค้นหา |
| Dialog ยืนยัน (ลบ, ออก, ล้างฟอร์ม) | `ConfirmDialog` | - |
| ฟอร์ม create/edit | `showModalBottomSheet` | - |
| แจ้งผลสำเร็จ/ผิดพลาด | `SnackBar` | - |
| ปุ่มเพิ่มรายการ | `FloatingActionButton` | - |

- ห้ามใช้ `TextField` / `TextFormField` ดิบ หรือ `DropdownButtonFormField` โดยตรง ถ้า `AppInput` / `AppLookupPickerField` / `AppDropdownField` รองรับ
- **Input style ต้องเป็น Pill-shaped เสมอ** (borderRadius 50) ใช้ `buildAppCapsuleInputDecoration()` helper
- Label ต้องอยู่ด้านบนฟิลด์ (ไม่ใช้ floating label) เหมือน `AppInput` และ `AppDateInput`
- ข้อความที่ผู้ใช้เห็นต้องเก็บใน `TransactionUiText` constants — ห้าม hardcode string ใน widget
- ห้ามใส่ข้อความอ้างอิงเชิงเอกสารใน UI เช่น `คู่มือหน้า ...`, `หน้า ...`, หรือวงเล็บอ้างหน้าคู่มือในข้อความที่ผู้ใช้เห็น
- ใช้ถ้อยคำไทยธรรมดา อ่านง่าย ตรงงาน และเน้นสิ่งที่ผู้ใช้ต้องทำจริง
- ทุก input ต้อง `readOnly` ที่ถูกต้อง ใช้ `enabled=false` สำหรับ disabled state

#### 4.3.0 วันที่ที่แสดงในแอป

- วันที่ทุกจุดที่ผู้ใช้เห็นใน Flutter ต้องแสดงเป็น **ภาษาไทย + ปี พ.ศ.** ผ่าน `ThaiDateFormatter` (`forntend/lib/core/utils/thai_date_formatter.dart`) หรือ `AppDateInput` / `AppInputAction.date` เท่านั้น
- รูปแบบมาตรฐาน: ตาราง/การ์ด/list ใช้ `ThaiDateFormatter.format(...)` เช่น `6 พ.ค. 2569`; ช่องเลือกวันที่ใช้ `AppDateFormat.thaiBuddhist` เช่น `พุธ 6 พฤษภาคม 2569`
- ห้ามแสดง ISO (`YYYY-MM-DD`) หรือปี ค.ศ. ใน UI ผู้ใช้ เว้นแต่เป็น export/debug/developer-only หรือเป็นค่าที่ระบบต้องส่งไป API/SQLite/query ภายในเท่านั้น
- เมื่อเก็บข้อมูลหรือส่ง query ให้ยังใช้ ISO (`ThaiDateFormatter.toIsoDate(date)` หรือค่าที่ datasource ต้องการ) แยกจากข้อความแสดงผลเสมอ

### 4.3.1 กฎการออกแบบ UI ของโปรเจกต์ (Flutter — canonical)

นี่คือ **มาตรฐานเลย์เอาต์และรูปแบบหน้าจอ** สำหรับแอป Flutter ใน repo นี้ — ใช้เมื่อเพิ่มหรือปรับหน้าที่โครงคล้ายกัน ไม่จำกัดเฉพาะโมดูลเงินยืม

ขอบเขตของ section นี้คือ visual layout, responsive behavior, component usage และ interaction pattern เท่านั้น; ถ้าเป็นเนื้อหาคู่มือผู้ใช้ให้ไปที่ `§6` และถ้าเป็นกฎอ้างอิงคู่มือการเงิน/บัญชีให้ไปที่ `§11`

**ขอบเขตที่ต้องยึดกฎนี้**

- หน้า **ฟอร์มเพิ่ม/แก้ไข** (หลายช่อง, บันทึก, อาจมีสรุปด้านล่าง)
- หน้า **รายละเอียด** ที่จัดเนื้อหาเป็นการ์ดหลายบล็อกใน scroll เดียวกัน
- หน้าอื่นที่ทีมออกแบบให้ “โทน” เดียวกับฟอร์มมาตรฐาน

**ข้อยกเว้น (ไม่บังคับทุกข้อ — แต่ยังต้องยึด §4.3 ตาราง component + §4.4 สี/font)**

- หน้าที่ต้องใช้พื้นที่เต็มแนวนอน (เช่น ตารางรายงานใหญ่, แดชบอร์ดกราฟเต็มจอ) อาจไม่ใส่ `ConstrainedBox(maxWidth: 720)` — แต่ยังใช้ `AppColors` / `AppTheme` spacing และ widget มาตรฐานของโปรเจกต์

**อ้างอิง implementation (gold standard)**

- **หลัก:** `forntend/lib/features/income/presentation/pages/income_add_page.dart` — ใช้เป็น template แรกเมื่อปรับ/สร้างหน้าฟอร์มธุรกรรมหรือหน้าฟอร์ม master ที่ต้องการโทนเดียวกัน
- **อ้างอิงเสริม:** `forntend/lib/features/loan/presentation/pages/loan_add_page.dart`, `forntend/lib/features/loan/presentation/pages/repay_loan_add_page.dart`

**โครงหน้า (scaffold + body)**

- `PopScope` / `SafeArea` / `Scaffold` ตาม flow หน้าที่มี (ถ้าต้อง intercept กลับ — ยึดแบบหน้า loan)
- `body`: `GestureDetector` (แตะพื้นที่ว่างแล้ว `unfocus`) หุ้ม `SingleChildScrollView` ตั้ง `keyboardDismissBehavior: onDrag`
- เนื้อหาหลักของ scroll: `Align(alignment: Alignment.topCenter)` + `ConstrainedBox(constraints: BoxConstraints(maxWidth: 1440))` + `Column(crossAxisAlignment: stretch)` — ตามแบบ `income_add_page.dart` เพื่อรองรับฟอร์มที่มีหลายคอลัมน์บนจอใหญ่/Windows

**หัวหน้าแบบฟอร์ม + คำแนะนำ**

- ใช้ `TransactionFormHeader` (หรือ widget ร่วมที่ทีมกำหนดให้เทียบเท่า) เมื่อเป็นหน้าฟอร์มธุรกรรม/เอกสาร — ไอคอนในกล่องสีธีมฟีเจอร์, หัวข้อ, subtitle, quick hint ตามแบบ `income_add_page.dart`
- สำหรับ **ฟอร์มตั้งค่าสั้น / ฟอร์มข้อมูลพื้นฐาน** ที่มีชื่อหน้าอยู่ใน `AppBar` ชัดแล้ว (เช่น ข้อมูลโรงเรียน): ไม่ต้องแสดง `TransactionFormHeader` หรือกล่องคำอธิบายซ้ำใน body; ให้ย้ายคำอธิบาย/วิธีใช้ไปไว้ในปุ่ม help `?` บน `AppBar` ผ่าน `PageGuideDialog` แทน เพื่อให้ body เริ่มที่การ์ดฟอร์มทันที

**การ์ดและหัวข้อย่อย**

- กล่องเนื้อหา: `Container` พื้นหลังการ์ด (`AppColors` card), `BorderRadius` / `Border` ตาม `AppTheme` แบบหน้าอ้างอิง
- แบ่งบล็อกด้วยแถวหัวข้อสไตล์ `income_add_page.dart` (ไอคอน `colorScheme.primary` ขนาดเล็ก + หัวข้อตัวหนาเล็ก) แล้วคั่น **`Divider`** ระหว่างส่วน

**เลย์เอาต์แบบคอลัมน์ (responsive)**

- หุ้มเนื้อหาการ์ดด้วย `LayoutBuilder` อ่าน `constraints.maxWidth` ของการ์ด แล้วคำนวณ `contentWidth` หลังหัก padding แนวนอน
- เกณฑ์มาตรฐานแบบ `income_add_page.dart`: `contentWidth >= 1180` → 4 คอลัมน์, `>= 900` → 3 คอลัมน์, `>= 560` → 2 คอลัมน์, ต่ำกว่าเกณฑ์ → 1 คอลัมน์
- ใช้ grid แบบ `Wrap` + field span เพื่อให้ field ที่เกี่ยวข้องจัดคอลัมน์ได้ยืดหยุ่น; ฟิลด์ยาว (picker ยาว, หมายเหตุหลายบรรทัด, รายละเอียด) ให้ span หลายคอลัมน์หรือเต็มความกว้างตามความหมาย

**ฟิลด์เปิด picker / read-only**

- ห้ามใช้ `IconButton` แยกข้างช่องแล้วจับ `padding.top` ให้ตรงกับช่อง — ไอคอนเปิดรายการต้องอยู่ใน suffix ของ `AppInput` / `AppLookupPickerField` เดียวกัน
- Lookup picker ต้องมี suffix icon เปิดรายการ **ตัวเดียว** เท่านั้น ห้ามซ้อนทั้งลูกศรและไอคอน list ในช่องเดียว เพราะทำให้ช่องดูรกและความหมายซ้ำกัน
- ฟิลด์ใด ๆ ที่ผู้ใช้ต้อง “เลือกจากรายการ” ในฟอร์มและมีข้อมูล **มากกว่า 6 แถว** ให้ใช้ `AppLookupPickerField` ไม่สร้าง picker field custom ด้วย `AppInput` เอง ยกเว้นมีเหตุผลเฉพาะและต้องคงหน้าตา/พฤติกรรมเทียบเท่า `AppLookupPickerField`
- ถ้ารายการมี **6 แถวหรือน้อยกว่า** ให้ใช้ `AppDropdownField` ได้ เพื่อให้ผู้ใช้เลือกเร็วโดยไม่ต้องเปิด bottom sheet
- Lookup ที่ผู้ใช้เลือกจาก master data หรือรายการธุรกิจ เช่น `หมวดรายรับ`, `แหล่งเงิน`, `วิธีรับเงิน`, `ผู้รับ/ผู้จ่าย`, `สมุดใบเสร็จ` ถ้าข้อมูลอาจเกิน 6 แถวหรือโหลดจากฐานข้อมูล ให้แสดงเป็น **read-only input picker** ด้วย `AppLookupPickerField` ไม่ใช้ dropdown ฝังในฟอร์ม
- Picker ต้องเปิดรายการใน bottom sheet/dialog ที่ค้นหาได้; ถ้าฟิลด์ต้องรองรับการล้างค่า ให้ใส่ action ล้างใน picker/dialog หรือออกแบบเฉพาะโดยไม่ทำให้ suffix icon หลักเกินหนึ่งตัว
- Bottom sheet/dialog ของ picker ต้องใช้พื้นหลังทึบ (`AppColors.cardWhite` หรือสีการ์ดของธีม) ครอบทั้ง header/search/list เพื่อไม่ให้เห็น UI ด้านหลังลอดผ่าน
- ถ้าต้องมี drag handle ใน picker bottom sheet ให้ render handle เองภายใน header ที่มีพื้นหลังทึบ ไม่ใช้ `showDragHandle: true` ของระบบเมื่อทำให้พื้นที่ chrome ด้านบนคุมสีไม่ได้

**ตัวเลขเงิน**

- ใช้ `AppInputAction.number(allowDecimal: true)` และ `textAlign: TextAlign.right` ตามแบบ `income_add_page.dart` เมื่อเป็นจำนวนเงิน

**หมายเหตุหลายบรรทัด**

- ตั้ง `minLines` (เช่น 2), `maxLines` (เช่น 5), `TextInputAction.newline`

**แถบบันทึก / สถานะพร้อมบันทึก**

- ฟอร์มที่มี validation ซับซ้อน: แสดงกล่องสถานะพร้อมบันทึก + สรุปยอด/ปุ่มช่วย (`TransactionSummaryActions` หรือ widget ร่วมที่เทียบเท่า) ให้สอดคล้องกับหน้าอ้างอิง

**AppBar ฟอร์ม (เมื่อใช้แถบบันทึกบน App bar)**

- พื้นหลังการ์ด, `toolbarHeight` คงที่, `elevation: 0`, เส้น `Divider` ใต้แถบ, ปุ่มหลักชัด (บันทึก / ยกเลิก / ล้างฟอร์มเมื่อมีเหตุผล)
- จัด `AppBar.actions` เป็นกลุ่มชิดขวาที่มี `Padding` ปลายแถบอย่างน้อย `AppTheme.sp12` เพื่อไม่ให้ปุ่มชนขอบหรือชน desktop titlebar padding
- ปุ่มช่วยเหลือ/ล้างฟอร์มเป็น `IconButton` โทนรองและอยู่ก่อนกลุ่ม decision action; ใช้เมื่อจำเป็นเท่านั้น และต้องมี `tooltip`
- ในโหมดแก้ไขให้เรียง action เป็น `ยกเลิก` ก่อน `บันทึก`; ปุ่มหลัก (`บันทึก`) ต้องอยู่ขวาสุดและใช้ `AppBarActionButton(isPrimary: true)` เพื่อให้ผู้ใช้เห็น action สำคัญชัดเจน
- ห้ามวาง action หลักหลายปุ่มติดกันแบบน้ำหนักเท่ากันจนแยกไม่ออกว่า action ไหนสำคัญที่สุด
- ถ้าหน้านั้นใช้ `AppBarActionButton(isPrimary: true)` เป็น action หลักแล้ว ไม่ต้องใส่ปุ่ม `บันทึก` ซ้ำใน body/action card ด้านล่าง ยกเว้นเป็นฟอร์มธุรกรรมที่มีสรุปยอดหรือ validation ซับซ้อนตาม pattern `TransactionSummaryActions`

### 4.3.2 ป้องกัน Flutter Infinite Constraints

เมื่อสร้างหน้าใหม่ ฟอร์มใหม่ dialog/bottom sheet ใหม่ หรือฟังก์ชันสร้าง widget ใหม่ ต้องไม่ส่ง constraint ที่มีความกว้าง/สูงเป็น infinity ให้ widget ที่ต้อง layout เป็นกล่องจริง เช่น `Material`, `Card`, `PhysicalModel`, `ElevatedButton`, `OutlinedButton`, `FilledButton`, `Container`, `SizedBox`

- ห้ามตั้ง global theme หรือ reusable widget เป็น `minimumSize: Size(double.infinity, ...)`, `fixedSize: Size(double.infinity, ...)`, หรือ `BoxConstraints(minWidth: double.infinity)` เพราะจะทำให้เกิด `FlutterError: BoxConstraints forces an infinite width` เมื่อปุ่ม/การ์ดถูกวางใน `Row`, dialog, popup, `UnconstrainedBox`, หรือพื้นที่ที่ parent ยังไม่ได้กำหนดความกว้างแน่นอน
- ถ้าต้องการ full width ให้กำหนดที่ call site เท่านั้น และใช้ใน parent ที่มีความกว้างจำกัดแล้ว เช่น `SizedBox(width: double.infinity, child: AppButton(...))`, `Expanded(child: ...)` ใน `Row`, หรือ `ConstrainedBox(maxWidth: ..., child: ...)` รอบ dialog/form
- ใน dialog/custom popup ต้องมีกรอบจำกัดเสมอ เช่น `Center` + `ConstrainedBox(maxWidth: 460, ...)` และ widget ภายในห้ามบังคับความกว้างเป็น infinity ถ้า parent ยังเป็น loose/unbounded constraints
- ก่อนจบงาน UI ใหม่หรือฟังก์ชัน widget ใหม่ ให้ทดสอบเปิดหน้าจอจริงอย่างน้อยบนขนาด desktop/window ที่ใช้พัฒนา และตรวจว่าไม่มี error ประเภท `BoxConstraints forces an infinite width/height`, overflow หลัก, หรือ render exception ใน console

### 4.3.3 Bottom Sheet ประวัติ / รายละเอียด / รายการสั้น

- Bottom sheet ที่ใช้แสดง **ประวัติ, รายละเอียด, log, summary หรือ list สั้น** ต้องสูงตามจำนวนข้อมูลจริง ไม่เปิดเต็มจอหรือใช้ `initialChildSize` สูงคงที่โดยไม่จำเป็น
- ใช้ widget กลาง `AdaptiveContentSheet` จาก `forntend/lib/widgets/sheet/adaptive_content_sheet.dart` เป็นค่าเริ่มต้นสำหรับ sheet กลุ่มนี้
- โครงมาตรฐาน: `showModalBottomSheet(isScrollControlled: true, backgroundColor: Colors.transparent)` + `AdaptiveContentSheet(title: ..., child: ...)`
- สถานะ `loading`, `empty`, `error` ให้ใช้ความสูงพอดีอ่านง่าย เช่น `SizedBox(height: 160)` ไม่กินพื้นที่ทั้งจอ
- เมื่อข้อมูลเยอะ ให้จำกัดความสูงสูงสุดประมาณ 90% ของหน้าจอ แล้วใช้ `Flexible(child: ListView.builder(shrinkWrap: true, ...))` หรือเทียบเท่าเพื่อให้ scroll ภายใน sheet
- ถ้าเป็น picker/search bottom sheet ที่ต้องค้นหารายการยาว ใช้ pattern picker เดิมได้ แต่ยังต้องมีพื้นหลังทึบและไม่ให้ chrome ด้านบนโปร่งตาม §4.3.1

### 4.3.4 มาตรฐาน Popup / Form Sheet

ใช้ component กลางแทน popup เฉพาะหน้า เพื่อให้ UX และ theme สอดคล้องกันทั้งแอป:

- **ฟอร์มย่อย / รายละเอียด / summary / list ยาวใน popup:** ใช้ `showModalBottomSheet(isScrollControlled: true, showDragHandle: false, backgroundColor: Colors.transparent)` + `AdaptiveContentSheet`
- **เลือกรายการจาก master data หรือรายการธุรกิจ:** ใช้ `AppLookupPickerField` เป็นหลัก; ถ้าข้อมูลไม่เกิน 6 รายการและไม่ต้องค้นหา ใช้ `AppDropdownField`
- **ยืนยัน action:** ใช้ `ConfirmDialog` เช่น ลบ, ล้างฟอร์ม, ออกจากหน้าโดยไม่บันทึก, ไปแก้ข้อมูลตั้งต้น
- **คู่มือ/คำแนะนำของหน้า:** ใช้ `PageGuideDialog`
- **แจ้งผลสั้น:** ใช้ `SnackBar` หรือ notification service กลางของโปรเจกต์
- หลีกเลี่ยง `AlertDialog` ดิบในงานใหม่ ถ้าจำเป็นต้องใช้ ต้องมีเหตุผลเฉพาะและคง `AppColors`, font `Kanit`, spacing และ action style ให้สอดคล้องกับ widget กลาง
- ใน bottom sheet ต้องรองรับ keyboard ด้วย `MediaQuery.viewInsetsOf(context).bottom`, จำกัดความกว้างด้วย `ConstrainedBox`, และไม่ใช้ `showDragHandle: true` ถ้าทำให้พื้นหลังส่วน chrome ไม่ทึบ
- Popup ที่มีผลลัพธ์กลับไปยังหน้าเดิมต้อง return ค่าเดิมให้ครบ เช่น `bool`, `String?`, `int?` เพื่อไม่เปลี่ยน behavior ธุรกิจ

### 4.4 สีและ Font

- สีหลัก: `AppColors.of(context)` — `.textPrimary`, `.textSecondary`, `.textHint`
- สีเน้น: `Theme.of(context).colorScheme.primary`
- Font: `fontFamily: 'Kanit'` ทุกครั้งที่เขียน `TextStyle` เอง
- Inside dialog/bottom sheet ให้ดึง context ของ overlay: `AppColors.of(dialogContext)`

### 4.5 การแยกไฟล์

ห้ามวางทุกอย่างในไฟล์ `*_page.dart` เดียว — โครงขั้นต่ำ:

```
presentation/
├── pages/*_page.dart            # state ระดับหน้า + ประกอบ widget ย่อย
├── widgets/*_filter_section.dart
├── widgets/*_item_card.dart
├── widgets/*_form_sheet.dart
└── models/*_view_model.dart
```

### 4.6 Desktop Titlebar + Embedded-in-Home Pattern

- โหมด Desktop (Windows/Linux/macOS) ใช้ custom titlebar ผ่าน `window_manager` + `desktop_window_chrome.dart`
- ห้ามกันพื้นที่ขวาทั้งหน้าจอเพื่อหลบปุ่มย่อ/ขยาย/ปิด — ให้กันเฉพาะ `AppBar.actions` ผ่าน theme (`AppBarTheme.actionsPadding`)
- หน้าที่เปิดได้ทั้ง standalone และใน `HomeScreen` ต้องรองรับ `embeddedInHome` และใช้ `EmbeddedHomeScaffold` (`forntend/lib/widgets/layout/embedded_home_scaffold.dart`)
- เมื่อ `embeddedInHome = true`:
  - ห้ามแสดง title ซ้ำกับ `HomeScreen` AppBar
  - ให้คงเฉพาะส่วนที่จำเป็นของหน้านั้น (เช่น `TabBar`/filter/actions)
- เมื่อ `embeddedInHome = false`: ต้องแสดง AppBar ของหน้าตามปกติ (รองรับเปิด route เดี่ยว)

---

## 5. กฎฐานข้อมูล (DB Standards)

### 5.1 Foreign Keys

- **ทุก** คอลัมน์ที่อ้างตารางอื่น ต้องมี FK constraint ทั้ง localdb (SQLite) และ serverdb (MariaDB)
- SQLite: `PRAGMA foreign_keys = ON` ใน `app_database.dart` ทุกครั้ง

### 5.2 ON DELETE / ON UPDATE

| กรณี | ON DELETE | ON UPDATE |
|---|---|---|
| เอกสารหลัก → แถวลูก (1:N) เช่น income → income_sub | `CASCADE` | `CASCADE` |
| ธุรกรรมอ้าง master (party, budget_source) | `SET NULL` | `CASCADE` |
| อ้าง lookup ไม่บังคับ (money_type, member) | `SET NULL` | `CASCADE` |

- **ห้าม CASCADE จาก master ไปลบเอกสารการเงินหลัก** (เช่น ลบ `party` แล้วลบ `income`) — ใช้ `SET NULL` เท่านั้น

### 5.3 Migration Pattern (localdb SQLite)

เมื่อต้องแก้ตาราง:
1. สร้างตาราง `*_new` ที่มี FK schema ใหม่
2. Copy แถวพร้อม cleanup orphan reference
3. Rename/swap ตาราง
4. Bump `dbVersion` ใน `app_database.dart`
5. เพิ่ม comment สั้นในโค้ดว่า version นี้แก้อะไร

### 5.4 ลำดับสร้างตารางใน `_onCreate`

สร้าง **parent ก่อน child** เสมอ เช่น `party` → `income` → `income_sub`

---

## 6. คู่มือผู้ใช้ (Usage Guide) — แยกจากกฎออกแบบ UI

ส่วนนี้ใช้สำหรับ **เนื้อหา help/usage flow ที่ผู้ใช้เปิดอ่านในแอป** ไม่ใช่มาตรฐาน layout, component, spacing หรือ responsive design; เรื่องออกแบบ UI ให้ใช้ `§4.3` ถึง `§4.6`

**ทุกครั้งที่เพิ่มหรือเปลี่ยน flow ที่ผู้ใช้เห็น** ต้องอัปเดตพร้อมกัน:

1. `forntend/lib/features/help/presentation/pages/usage_flow_helper_page.dart`
2. `forntend/lib/constants/transaction_ui_text.dart` (คีย์ `usageFlow*`)
3. ลิงก์นำทางใน `UsageFlowHelperPage` ต้องพาไปหน้าจริงได้เมื่อกด — ห้ามเขียนแค่ข้อความบอก

> ถ้าเป็น feature ภายในที่ผู้ใช้ไม่เห็น ให้ระบุในสั้น ๆ ใน commit/PR ว่าทำไมไม่ต้องอัปเดต

---

## 7. Security

- **ห้าม commit** ค่า secret, password, JWT secret, database credential ใน code หรือ config ใดๆ — ใช้ `.env` เสมอ และ `.env` ต้องอยู่ใน `.gitignore`
- ตรวจสอบ input จากผู้ใช้ที่ boundary เสมอ (API layer) ก่อน query DB
- JWT: ตรวจ token ทุก endpoint ที่แก้/เพิ่ม/ลบข้อมูล

---

## 8. การทดสอบ

- Feature ใหม่ที่มี business logic ให้มี unit test อย่างน้อย **happy path + error path**
- ก่อน push: รัน `flutter analyze` ให้ผ่านโดยไม่มี error (warning ยอมรับได้ถ้ามีเหตุผล)
- Backend: รัน migration บน DB ทดสอบก่อน push ทุกครั้ง

---

## 9. ข้อห้ามทั่วไป

| ห้าม | เหตุผล |
|---|---|
| แก้ migration เก่าที่ commit แล้ว | ทำให้ DB ของสมาชิกคนอื่น inconsistent |
| เปลี่ยนชื่อโฟลเดอร์ `forntend/` | กระทบ path ทั้งโปรเจกต์ |
| Dio/HTTP โดยตรงใน widget/page | ละเมิด Clean Architecture + local-first |
| Hardcode สี/font/string ใน widget | ทำให้ theme และ i18n แตก |
| FK แบบ "logical เท่านั้น" ไม่มี constraint จริง | ข้อมูล orphan บน production |
| ลบไฟล์/branch/ตารางโดยไม่แจ้งทีม | งานคนอื่นอาจพัง |

---

## 10. Checklist ก่อน Merge

- [ ] `flutter analyze` ผ่านโดยไม่มี error
- [ ] Migration รันได้บน DB สะอาด (`npm run migrate`)
- [ ] FK ทั้ง localdb และ serverdb ตรงกัน (ถ้าแตะ DB)
- [ ] UI ใหม่ใช้ `AppInput`, `AppDropdownField`, `ConfirmDialog` ตามกฎ
- [ ] หน้าฟอร์ม/รายละเอียดที่โครงคล้ายมาตรฐาน ยึด **§4.3.1** (เลย์เอาต์ + การ์ด + responsive + suffix ใน `AppInput`)
- [ ] UI/widget ใหม่ไม่สร้าง infinite constraints ตาม **§4.3.2** และเปิดหน้าจอจริงแล้วไม่มี render exception
- [ ] อัปเดตคู่มือ (`UsageFlowHelperPage`) ถ้าแตะ flow ที่ผู้ใช้เห็น
- [ ] ไม่มี secret/credential ใน commit
- [ ] PR มีคำอธิบายสั้นๆ ว่าเปลี่ยนอะไร
- [ ] หาก PR แตะงานการเงิน/บัญชี/ทะเบียน/รายงาน ให้ผ่าน checklist ในข้อ `12` เพิ่มเติม

---

## 11. คู่มือการเงินและกฎโดเมน (Financial Module Dev Spec)

> อ้างอิงหลัก: `docs/document-ref/คู่มือการปฎิบัติงานการเงิน.md`  
> ใช้ section นี้เป็นกติกา implement ฝั่ง dev (frontend/backend/db) สำหรับ feature การเงิน
> section นี้เก็บ business rule, workflow, mapping และ checklist ที่อิงคู่มือการเงิน ไม่ใช่กฎออกแบบ UI; ถ้าต้องจัด layout หรือ component ให้กลับไปใช้ `§4.3`

### 11.1 Business Domains & Source of Truth

- ระบบการเงินต้องรองรับ 3 โดเมนหลัก: `budget`, `treasury_income`, `off_budget`
- กลุ่มรายการจากไฟล์ FE ทั้ง 13 หมวดให้ map เป็น `off_budget` เป็นค่าเริ่มต้น
- ห้าม hardcode mapping ใน widget/page; ต้องแยกเป็น config/constants หรือ master table

### 11.2 Required Rule Engine (ขั้นต่ำที่ต้อง enforce)

- ต้องมีชั้น rule ตรวจเงื่อนไขก่อนบันทึก/อนุมัติ เช่น
  - วงเงินเก็บรักษา
  - เส้นตายนำส่ง (เช่น รายได้แผ่นดิน/ภาษีหัก ณ ที่จ่าย)
  - เงื่อนไขเงินยืม (ห้ามยืมใหม่เมื่อยังไม่ปิดหนี้เก่า)
- ฝั่ง UI ห้ามเป็นแหล่งกฎหลักเพียงที่เดียว; backend หรือ domain service ต้อง validate ซ้ำเสมอ
- Validation error ต้องอ่านรู้เรื่องโดยผู้ใช้ทางการเงิน (ไม่ใช้ข้อความ generic)

### 11.3 Workflow State (แนะนำมาตรฐาน)

- รายการรับ/จ่ายควรมี state ชัดเจนอย่างน้อย:
  - `draft` -> `submitted` -> `approved` -> `posted` -> `reconciled`
- รายการที่เกี่ยวกับฝาก/ถอนให้มี event log แยก เช่น `cash_deposit`, `cash_withdraw`, `treasury_deposit`
- เงินประกันสัญญาต้องมีสถานะ lifecycle เพิ่ม: `held` -> `requested_refund` -> `refunded`

### 11.4 Data Model Minimum Fields

- ตารางธุรกรรมการเงินต้องมีขั้นต่ำ:
  - `money_domain` (`budget|treasury_income|off_budget`)
  - `money_type_code` (ชนิดย่อย)
  - `doc_no`, `doc_date`
  - `amount`, `counterparty`
  - `status`, `approved_by`, `approved_at`
  - `created_by`, `created_at`, `updated_at`
- ตารางเงินยืมต้องมี:
  - `borrower_id`, `contract_no`, `borrow_date`, `due_date`
  - `borrow_amount`, `cleared_amount`, `outstanding_amount`, `borrow_status`
- ห้ามลบข้อมูลธุรกรรมจริง; ใช้ soft delete หรือ reverse entry ตามบริบทบัญชี

### 11.5 Reconciliation & Daily Closing

- ต้องรองรับการปิดวัน (`daily closing`) และบันทึก snapshot ยอดคงเหลือตามประเภทเงิน
- ต้องมี monthly reconciliation กับยอดธนาคาร (bank statement)
- หากยอดไม่ตรงต้องบันทึก reason code ได้ (เช่น เช็คค้างขึ้นเงิน, โอนเข้าแล้วยังไม่รับ)

### 11.6 Receipt & Document Control

- เลขที่ใบเสร็จต้องควบคุมไม่ซ้ำ และตรวจย้อนหลังเส้นทางเอกสารได้
- กรณียกเลิกเอกสารต้องเก็บสถานะยกเลิก + เหตุผล + ผู้ดำเนินการ
- ระบบต้องรองรับรายงานสถานะการใช้ใบเสร็จรายปีตามช่วงเลขที่

### 11.7 Deadline-Critical Checks (must-have)

- รายได้แผ่นดิน:
  - แจ้งเตือนเมื่อยังไม่ได้นำส่งรอบเดือน
  - หากยอดคงเก็บรักษาเกินเกณฑ์ที่กำหนด ต้องแจ้งเตือนเส้นตาย 3 วันทำการ
- ภาษีหัก ณ ที่จ่าย:
  - แจ้งเตือน deadline ภายใน 7 วันหลังสิ้นเดือน
- เงินยืม:
  - แจ้งเตือนก่อนครบกำหนด และ escalated alert เมื่อ overdue

### 11.8 API/Service Design Rules

- แยก endpoint ตาม intent ชัดเจน เช่น `receive`, `approve`, `post`, `close-day`, `reconcile`
- ทุก action สำคัญต้องมี audit trail (who/when/before/after)
- ใช้ transaction เมื่อกระทบหลายทะเบียน/หลายตารางพร้อมกัน

### 11.9 การเชื่อมกับ UI โดยไม่ปนกฎออกแบบ

- ฟอร์มการเงินต้องใช้ component มาตรฐานของโปรเจกต์ตาม `§4.3` (`AppInput`, `AppDropdownField`, `AppDateInput`, `AppLookupPickerField`)
- **เลย์เอาต์และรูปแบบหน้าจอ:** ยึด `§4.3.1` โดยใช้ `forntend/lib/features/income/presentation/pages/income_add_page.dart` เป็น template หลัก
- กฎโดเมน เช่น สถานะเอกสาร, เส้นตาย, วงเงิน, mapping 13 หมวด และเงื่อนไขตามคู่มือ ต้องอยู่ใน domain/backend/rule layer ตาม `§11` ไม่ฝังเป็นกฎหลักใน widget
- ข้อความที่ผู้ใช้เห็นให้เป็นภาษาไทยใช้งานจริงผ่าน `TransactionUiText`; ห้ามใส่อ้างอิง `คู่มือหน้า ...` หรือข้อความเชิงเอกสารลงใน label/help text ของฟอร์ม
- แสดงป้ายสถานะเอกสารและเส้นตายชัดเจนในรายการ/รายละเอียด แต่ข้อความต้องเป็นภาษาผู้ใช้ ไม่ใช่ข้อความอ้างคู่มือ
- มี confirmation dialog สำหรับ action เสี่ยง เช่น post รายการ, ปิดวัน, ยกเลิกเอกสาร

### 11.10 Testing Minimum for Financial Features

- Unit tests:
  - rule validation (วงเงิน/กำหนดเวลา/เงื่อนไขยืมเงิน)
  - state transition ที่อนุญาต/ไม่อนุญาต
- Integration tests:
  - flow รับเงิน -> ลงทะเบียน -> ปิดวัน
  - flow ฝาก/ถอน -> reconciliation
- Regression tests:
  - mapping 13 หมวด `off_budget` ต้องไม่แตก
  - รายงานประจำวัน/เดือนยังคำนวณยอดถูกต้อง

---

## 12. PR Checklist สำหรับงานการเงิน (Finance-PR Gate)

ใช้ checklist นี้ทุกครั้งที่ PR แตะ feature การเงิน/บัญชี/ทะเบียน/รายงาน

### 12.1 Domain & Mapping

- [ ] ระบุชัดเจนว่า PR นี้แตะโดเมนไหน: `budget` / `treasury_income` / `off_budget`
- [ ] กรณีเป็นรายการจากชุด FE 13 หมวด: map ไป `off_budget` ถูกต้อง
- [ ] ไม่ hardcode mapping ในหน้า UI; mapping อยู่ใน config/master/rule layer

### 12.2 Rule Enforcement

- [ ] มี validation rule ตามกติกา (วงเงิน, deadline, เงื่อนไขเงินยืม) ในชั้น domain/backend
- [ ] UI ทำหน้าที่ช่วยกรอกและแจ้งเตือน แต่ไม่ใช่แหล่งกฎเดียว
- [ ] ข้อความ error สื่อความหมายเชิงงานการเงิน (ไม่ generic)

### 12.3 Workflow & Auditability

- [ ] สถานะเอกสาร/รายการไม่ข้ามขั้นโดยไม่มีเหตุผล
- [ ] action สำคัญมี audit trail (`who`, `when`, `before`, `after`)
- [ ] กรณียกเลิกรายการมี reason และผู้ดำเนินการครบ

### 12.4 Data & Transaction Safety

- [ ] ตาราง/ฟิลด์สำคัญของงานการเงินครบ (`money_domain`, `money_type_code`, `status`, `approved_*`, ฯลฯ)
- [ ] งานที่กระทบหลายตารางใช้ transaction
- [ ] ไม่มีการลบธุรกรรมจริงแบบทำให้ตรวจสอบย้อนหลังไม่ได้ (ใช้ soft delete/reverse ตามบริบท)

### 12.5 Closing / Reconciliation / Reports

- [ ] flow ปิดวัน (`daily closing`) ยังทำงานครบและยอดคงเหลือตรง
- [ ] flow กระทบธนาคารมี reconciliation รองรับ
- [ ] รายงานรายวัน/รายเดือน/รายปี ที่เกี่ยวข้องยังออกผลถูกต้อง

### 12.6 Receipt & Document Control

- [ ] เลขที่ใบเสร็จไม่ซ้ำและตรวจย้อนหลังได้
- [ ] เงื่อนไขใบเสร็จยกเลิก/คงค้างปลายปีไม่ถูกทำลาย
- [ ] หลักฐานจ่าย (ต้นเรื่อง+อนุมัติ+ใบสำคัญ) ยังครบตาม flow

### 12.7 Deadline-Critical Scenarios

- [ ] รายได้แผ่นดิน: ยัง enforce รอบนำส่งรายเดือนและเงื่อนไขเร่งนำส่งเมื่อเกิน threshold
- [ ] ภาษีหัก ณ ที่จ่าย: ยัง enforce เส้นตายหลังสิ้นเดือน
- [ ] เงินยืม: ห้ามยืมใหม่เมื่อหนี้เก่ายังไม่ปิด + มี overdue alert/ติดตาม

### 12.8 Test Evidence (ต้องแนบใน PR)

- [ ] แนบผลทดสอบ unit/integration ที่เกี่ยวข้อง
- [ ] แนบกรณีทดสอบ happy path + edge/error path อย่างน้อย 1 ชุดต่อ flow ที่แตะ
- [ ] แนบหลักฐานว่า mapping 13 หมวด FE ยังไม่ regress (ภาพ/คลิป/ผลทดสอบ)

### 12.9 Reviewer Quick Decision

- [ ] **Approve ได้** เมื่อผ่าน checklist ทุกหมวดที่เกี่ยวข้อง
- [ ] **Request changes** ทันที หากพบการข้ามกฎการเงินสำคัญ (rule/deadline/audit trail)

---

## 13. PR Description Template (งานการเงิน)

คัดลอก template นี้ไปใช้ใน PR ที่แตะงานการเงิน/บัญชี:

```md
## Summary
- [ ] แตะโดเมน: `budget` / `treasury_income` / `off_budget`
- [ ] ฟีเจอร์/โมดูลที่เปลี่ยน:
- [ ] เหตุผลเชิงธุรกิจ/ปัญหาที่แก้:

## Scope of Change
- Backend:
- Frontend:
- Database / Migration:
- Reports / Reconciliation:

## Finance Rules Impact
- [ ] วงเงิน/กำหนดเวลา ที่เกี่ยวข้อง:
- [ ] เงื่อนไขเงินยืมที่เกี่ยวข้อง:
- [ ] Receipt/Document control ที่เกี่ยวข้อง:
- [ ] Audit trail ที่เพิ่ม/เปลี่ยน:

## Mapping & Data Integrity
- [ ] Mapping 13 หมวด FE -> `off_budget` ยังถูกต้อง
- [ ] ไม่มี hardcode mapping ใน widget/page
- [ ] ข้อมูลย้อนหลังไม่เสีย (soft delete/reverse ตามบริบท)
- [ ] ใช้ transaction ในจุดที่กระทบหลายตาราง

## Test Evidence
- [ ] Unit tests (แนบผล/คำสั่ง):
- [ ] Integration tests (แนบผล/คำสั่ง):
- [ ] Happy path:
- [ ] Edge/Error path:
- [ ] Regression (mapping/report/reconcile):

## Screenshots / Videos (ถ้ามี UI)
- ก่อนแก้:
- หลังแก้:

## Risk & Rollback
- ความเสี่ยงหลัก:
- วิธีเฝ้าระวังหลัง deploy:
- วิธี rollback:

## Checklist (Finance-PR Gate)
- [ ] Domain & mapping
- [ ] Rule enforcement
- [ ] Workflow + auditability
- [ ] Data + transaction safety
- [ ] Closing / reconciliation / reports
- [ ] Receipt & document control
- [ ] Deadline-critical checks
- [ ] Test evidence ครบ
```

### 13.1 กติกาการใช้ Template

- PR งานการเงินต้องกรอกหัวข้อ `Finance Rules Impact` และ `Test Evidence` ทุกครั้ง
- หากแตะ workflow ปิดวัน/นำส่ง/เงินยืม ต้องแนบผลทดสอบ edge case อย่างน้อย 1 กรณี
- หากมี migration ต้องระบุผลทดสอบบนฐานข้อมูลสะอาดและข้อมูลเดิม (migration up/down หรือแผน rollback)

---

## 14. Registry, License และการแจกจ่าย

> เอกสารฉบับเต็ม (HTML): **`docs/registry-and-license.html`** — เปิดในเบราว์เซอร์หรือพิมพ์เป็น PDF  
> ออกแบบเพิ่มเติม: `release/docs/KEYGEN-DESIGN.md`, `docs/PRODUCT-TIERS.md`, `release/README-DISTRIBUTION.md`

### 14.1 แยกบริการ 3 ชั้น

| ชั้น | ที่อยู่ | หน้าที่ |
|------|---------|---------|
| ทดลองใช้บนเครื่อง | `forntend/lib/features/license/embedded_trial_license.dart` | `kEmbeddedTrialDays` — ไม่ผ่าน Registry |
| **Registry** | `registry-backend/` (พอร์ต 3802, DB `saccm_registry`) | keygen, activate, log, trial anchor, device |
| **Online API** | `backend/` (พอร์ต 3801) | ข้อมูลการเงิน, sync, JWT — **ห้าม** เก็บ license/device |

Online API เก็บแค่ `school_tenant` (แมป `school_code` → `db_name`) สร้างจาก Registry ตอน provision

### 14.2 กฎ Registry backend

- DB ชื่อ `saccm_registry` **แยกจาก** backend เสมอ — ห้ามใช้ `sacc`, `sacc_master`, `saccm_master`
- `INTERNAL_API_SECRET` ต้องตรงกับ Online API สำหรับ `POST /saccapi/internal/school/provision`
- รหัส `SACC-XXXX-XXXX-XXXX` เก็บเป็น bcrypt hash เท่านั้น — ห้าม log รหัสเต็ม
- Admin API ต้องมี header `X-License-Admin-Secret`
- แก้ schema Registry → migration ใหม่ใน `registry-backend/migrations/` เท่านั้น

### 14.3 กฎแอป Flutter ↔ Registry

- HTTP client: `LicenseRemoteDataSource` → base `registryBase` จาก `forntend/lib/config.dart`
- **`SACC_REGISTRY_BASE`** เป็น compile-time (`--dart-define`) — **ห้าม** ออกแบบให้ผู้ใช้เปลี่ยน Registry URL จาก Settings (ต่างจาก `SACC_API_BASE`)
- ข้อยกเว้น remote read ตาม §4.2: activation, validate, status, heartbeat, token, trial, admin license console
- `LicenseGate` + `EmbeddedTrialLicense.syncServerAnchorIfPossible()` เรียก `POST /registryapi/trial/start` แบบ background
- แพ็กเกจ online: `SessionRefreshListener` เรียก heartbeat + token refresh ผ่าน Registry

### 14.4 MasterDataSync หลัง activate

- เรียกเฉพาะแพ็กเกจ **ออนไลน์+ออฟไลน์** (`canSync` / `LicenseMode.canSyncOnline()`)
- ใช้ **Online API** (`MasterDataSyncService` → `BackupFullMirrorSync.runMastersOnly` + `menu/rows`) — **ไม่** เรียก Registry
- Sync ล้มเหลวหลัง activate ไม่ rollback license — แจ้งผู้ใช้และให้ sync ซ้ำจาก `LicenseInfoPage`
- ห้ามดึงรายการธุรกรรม (income/expense/loan) ใน master sync หลัง activate — ใช้เฉพาะ master/lookup tables

### 14.5 Build และแจกจ่าย

- Windows protected: `forntend/tool/build_windows_protected.ps1` — ส่ง `-RegistryBase` เป็น `--dart-define=SACC_REGISTRY_BASE=...`
- Release โรงเรียน: `release/scripts/build-release.ps1` — บังคับ `-RegistryBase` + preflight HTTPS
- เปลี่ยน endpoint production → build ใหม่ด้วย dart-define ที่ถูกต้อง (ไม่พอแค่แก้ server)
- เมื่อแก้ flow Registry, activate, trial, หรือ master sync หลัง activate ต้องอัปเดต **`docs/registry-and-license.html`** และ §14 นี้พร้อมกัน
