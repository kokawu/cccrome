@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0ccbuild.ps1" %*
exit /b %errorlevel%
