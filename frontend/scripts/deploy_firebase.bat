@echo off
title Estetica Lupatini - Deploy Firebase Hosting
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy_firebase.ps1" %*
pause
