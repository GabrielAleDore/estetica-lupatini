# ==============================================================================
# Script de Deploy para Firebase Hosting - Estetica Lupatini
# Compila a versao mais recente do Flutter Web e publica no Firebase Hosting
# ==============================================================================

param (
    [string]$ProjectId = "estetica-lupatini-app"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Localiza dinamicamente a raiz do projeto e o diretorio frontend
if (Test-Path (Join-Path $ScriptDir "..\..\firebase.json")) {
    $ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
} elseif (Test-Path (Join-Path $ScriptDir "..\firebase.json")) {
    $ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..")).Path
} else {
    $ProjectRoot = (Get-Location).Path
}

if (Test-Path (Join-Path $ProjectRoot "frontend")) {
    $FrontendDir = Join-Path $ProjectRoot "frontend"
} else {
    $FrontendDir = $ProjectRoot
}

Set-Location $ProjectRoot

Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "  ESTETICA LUPATINI - DEPLOY NO FIREBASE HOSTING                " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "Projeto Firebase: $ProjectId" -ForegroundColor Cyan
Write-Host "Diretorio raiz:   $ProjectRoot" -ForegroundColor Gray

# 1. Configura o projeto Firebase
npx -y firebase-tools use $ProjectId

# 2. Compila a versao web mais recente caso nao exista ou atualiza
Write-Host ""
Write-Host "[1/2] Compilando Flutter Web para producao..." -ForegroundColor Yellow
Set-Location $FrontendDir
flutter build web --release --base-href /
if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha na compilacao do Flutter Web."
    exit 1
}

# 3. Publica no Firebase Hosting
Set-Location $ProjectRoot
Write-Host ""
Write-Host "[2/2] Publicando no Firebase Hosting..." -ForegroundColor Yellow
npx -y firebase-tools deploy --only hosting --project $ProjectId

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "=================================================================" -ForegroundColor DarkGreen
    Write-Host "  APLICATIVO PUBLICADO NO FIREBASE COM SUCESSO!                 " -ForegroundColor Green
    Write-Host "=================================================================" -ForegroundColor DarkGreen
    Write-Host "Acesse o seu sistema em:" -ForegroundColor White
    Write-Host "  https://${ProjectId}.web.app" -ForegroundColor Cyan
    Write-Host "  https://${ProjectId}.firebaseapp.com" -ForegroundColor Cyan
} else {
    Write-Host ""
    Write-Host "[AVISO] Nao foi possivel concluir o deploy automaticamente." -ForegroundColor Red
    Write-Host "Se esta e a primeira vez que publica, realize o login com sua conta Google executando:" -ForegroundColor Yellow
    Write-Host "  npx firebase-tools login" -ForegroundColor White
    Write-Host "E em seguida rode novamente este script!" -ForegroundColor Gray
}
