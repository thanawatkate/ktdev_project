@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%recover_flutter_windows.ps1"

if not exist "%PS_SCRIPT%" (
  echo [ERROR] File not found: "%PS_SCRIPT%"
  exit /b 1
)

echo Running Flutter Windows recovery...
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Recovery failed with exit code %EXIT_CODE%.
  exit /b %EXIT_CODE%
)

echo.
echo Recovery finished successfully.
exit /b 0
