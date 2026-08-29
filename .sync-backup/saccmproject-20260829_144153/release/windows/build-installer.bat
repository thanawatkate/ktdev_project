@echo off
setlocal
cd /d "%~dp0"

title SACCM Windows Installer Build

echo.
echo ========================================
echo   SACCM - Build Windows Installer
echo ========================================
echo.

where pwsh >nul 2>&1
if %ERRORLEVEL% equ 0 (
  pwsh -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-installer.ps1" %*
  set "EXIT_CODE=%ERRORLEVEL%"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build-installer.ps1" %*
  set "EXIT_CODE=%ERRORLEVEL%"
)

if not "%EXIT_CODE%"=="0" (
  echo.
  echo Build failed. See messages above.
  pause
  exit /b %EXIT_CODE%
)

echo.
echo Press any key to close...
pause >nul
exit /b 0
