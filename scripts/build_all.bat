@echo off
title Estetica Lupatini - Build Multiplataforma
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_all.ps1" %*
pause
