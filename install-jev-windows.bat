@echo off
setlocal
rem JEV local judging service - Windows installer bootstrap (ASCII only on purpose).
rem The real installer is jev/windows/install.ps1 on the site below.
title JEV installer
rem A PSModulePath inherited from PowerShell 7 breaks Windows PowerShell 5.1 cmdlets.
set "PSModulePath="
set "JEV_ORIGIN=https://genuineedu.pages.dev"
set "JEV_PS1=%TEMP%\jev-install-%RANDOM%%RANDOM%.ps1"
echo Downloading the JEV installer from %JEV_ORIGIN% ...
"%SystemRoot%\System32\curl.exe" -fsSL --retry 3 -o "%JEV_PS1%" "%JEV_ORIGIN%/jev/windows/install.ps1" 2>nul
if not exist "%JEV_PS1%" powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -UseBasicParsing -Uri '%JEV_ORIGIN%/jev/windows/install.ps1' -OutFile '%JEV_PS1%'"
if not exist "%JEV_PS1%" goto nodownload
powershell -NoProfile -ExecutionPolicy Bypass -File "%JEV_PS1%" -Origin "%JEV_ORIGIN%"
set "JEV_RC=%ERRORLEVEL%"
del "%JEV_PS1%" >nul 2>nul
if not "%JEV_RC%"=="0" goto failed
echo.
timeout /t 8
exit /b 0

:nodownload
echo.
echo [ERROR] Could not download the installer. Check the network and run this file again.
pause
exit /b 1

:failed
echo.
pause
exit /b %JEV_RC%
