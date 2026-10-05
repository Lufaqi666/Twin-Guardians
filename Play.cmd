@echo off
cd /d "%~dp0"
if exist "%~dp0builds\TwinGuardians\TwinGuardians.exe" if exist "%~dp0builds\TwinGuardians\TwinGuardians.pck" (
  start "" "%~dp0builds\TwinGuardians\TwinGuardians.exe" %*
  exit /b
)
start "" "%~dp0.tools\godot\4.7.2\Godot_v4.7.2-stable_win64.exe" --path "%~dp0game" %*
