@echo off
setlocal
set "SCHOOL=%~1"
if "%SCHOOL%"=="" set "SCHOOL=pilot"
set "VER=%~2"
if "%VER%"=="" set "VER=1.0.0+1"
cd /d "%~dp0..\scripts"
powershell -NoProfile -ExecutionPolicy Bypass -File ".\build-android-release.ps1" -SchoolSlug "%SCHOOL%" -Version "%VER%"
if errorlevel 1 exit /b 1
pause
