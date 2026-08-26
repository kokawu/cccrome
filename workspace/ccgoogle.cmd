@echo off
setlocal
powershell -ExecutionPolicy Bypass -File "%~dp0ccgoogle.ps1" %*
exit /b %errorlevel%
