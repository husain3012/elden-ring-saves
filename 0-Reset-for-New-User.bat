@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0scripts\Reset-Project.ps1"
if %errorlevel% neq 0 pause
