@echo off
powershell.exe -NoLogo -ExecutionPolicy Bypass -File "%~dp0scripts\List-Checkpoints.ps1"
if %errorlevel% neq 0 pause
