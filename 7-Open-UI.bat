@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -ExecutionPolicy Bypass -File "%~dp0scripts\UI-Launcher.ps1"
if %errorlevel% neq 0 pause