; Inno Setup script สำหรับ SACCM Windows
; ต้องติดตั้ง Inno Setup 6+ แล้วรัน build-installer.ps1 หรือ build-release.ps1 -BuildInstaller
;
; iscc release\windows\saccm-setup.iss /DMyAppVersion=1.0.0 /DBuildOutput=release\out\windows-staging

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

#ifndef BuildOutput
  #define BuildOutput "..\out\windows-staging"
#endif

#ifndef MyAppIcon
  #define MyAppIcon "..\..\forntend\windows\runner\resources\app_icon.ico"
#endif

#define MyAppName "SACCM"
#define MyAppPublisher "SACCM"
#define MyAppExeName "saccm.exe"
#define MyAppURL "https://github.com/saccmproject/saccmproject"
#define MyAppComments "School accounting and finance control (offline-first)"

; ── ระบบกันแกะโค๊ด ──────────────────────────────────────────────────
; integrity_manifest.json (เซ็น HMAC ตอน build) ต้องอยู่ใน BuildOutput
; ถูกสร้างโดย release\scripts\build-release.ps1 ผ่าน new_integrity_manifest.ps1
; ถ้าไม่มี = build ยังไม่ผ่านขั้นกันแกะโค๊ด → หยุด compile installer ทันที
#define IntegrityManifest "integrity_manifest.json"
#if !FileExists(AddBackslash(BuildOutput) + IntegrityManifest)
  #error integrity_manifest.json missing in BuildOutput - run build-release.ps1 first
#endif

#define VCRedistFile "redist\vc_redist.x64.exe"
#if !FileExists(AddBackslash(SourcePath) + VCRedistFile)
  #error vc_redist.x64.exe missing - run release\windows\ensure-vcredist.ps1 before building installer
#endif

[Setup]
AppId={{A8F3C2E1-9B4D-4F6A-8C1E-2D5F9A7B3C4E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
AppComments={#MyAppComments}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=..\out\installer
OutputBaseFilename=saccm-{#MyAppVersion}-setup
SetupIconFile={#MyAppIcon}
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
MinVersion=10.0
DisableProgramGroupPage=no
AllowNoIcons=yes
CloseApplications=force

[Languages]
Name: "thai"; MessagesFile: "compiler:Languages\Thai.isl"

[Tasks]
Name: "desktopicon"; Description: "สร้างทางลัดบน Desktop"; GroupDescription: "ทางลัด:"; Flags: unchecked
Name: "launchapp"; Description: "เปิด {#MyAppName} หลังติดตั้งเสร็จ"; GroupDescription: "หลังติดตั้ง:"; Flags: checkedonce

[Files]
; รวมทุกไฟล์ใน BuildOutput รวมถึง integrity_manifest.json (กันแกะโค๊ด)
; ไฟล์ถูกคัดลอกแบบ byte-identical → SHA-256 ใน manifest ยังตรงหลังติดตั้ง
Source: "{#BuildOutput}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; VC++ 2015-2022 x64 — ติดตั้งก่อนแอปถ้ายังไม่มี (PrepareToInstall)
Source: "{#VCRedistFile}"; DestDir: "{tmp}"; DestName: "vc_redist.x64.exe"; Flags: deleteafterinstall dontcopy

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Comment: "ระบบบัญชีควบคุมการเงินสถานศึกษา"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon; Comment: "ระบบบัญชีควบคุมการเงินสถานศึกษา"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "เปิด {#MyAppName}"; WorkingDir: "{app}"; Flags: nowait postinstall skipifsilent; Tasks: launchapp

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
// Microsoft Visual C++ 2015-2022 x64 (required by Flutter Windows)
function VCRedistInstalled: Boolean;
var
  Installed: Cardinal;
begin
  Result :=
    RegQueryDWordValue(HKLM64,
      'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
      'Installed', Installed) and (Installed = 1);
  if not Result then
    Result :=
      RegQueryDWordValue(HKLM,
        'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
        'Installed', Installed) and (Installed = 1);
end;

function VCRedistInstallSucceeded(ExitCode: Integer): Boolean;
begin
  { 0 = OK, 3010 = OK restart later, 1638 = newer runtime already present }
  Result := (ExitCode = 0) or (ExitCode = 3010) or (ExitCode = 1638);
end;

function InitializeSetup: Boolean;
begin
  Result := True;
  if not VCRedistInstalled then
    MsgBox(
      'ไม่พบ Microsoft Visual C++ 2015-2022 (x64) บนเครื่องนี้' + #13#10 +
      'ตัวติดตั้งจะติดตั้งรันไทม์นี้ให้อัตโนมัติก่อนเปิด SACCM' + #13#10#13#10 +
      'If Visual C++ x64 is missing, the installer will add it automatically.',
      mbInformation, MB_OK);
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
var
  ResultCode: Integer;
begin
  Result := '';
  NeedsRestart := False;
  if VCRedistInstalled then
    Exit;

  ExtractTemporaryFile('vc_redist.x64.exe');
  if not Exec(ExpandConstant('{tmp}\vc_redist.x64.exe'),
    '/install /quiet /norestart', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
  begin
    Result := 'ไม่สามารถรันตัวติดตั้ง Microsoft Visual C++ x64 ได้';
    Exit;
  end;

  if not VCRedistInstallSucceeded(ResultCode) then
  begin
    Result :=
      'ติดตั้ง Microsoft Visual C++ x64 ไม่สำเร็จ (รหัส ' +
      IntToStr(ResultCode) + ').' + #13#10 +
      'ดาวน์โหลดเอง: https://aka.ms/vs/17/release/vc_redist.x64.exe';
    Exit;
  end;

  if ResultCode = 3010 then
    NeedsRestart := True;

  if not VCRedistInstalled then
    Result :=
      'ยังตรวจไม่พบ Microsoft Visual C++ x64 หลังติดตั้ง' + #13#10 +
      'ลองดาวน์โหลดเอง: https://aka.ms/vs/17/release/vc_redist.x64.exe';
end;

