# ==============================================================================
# Script de Automacao de Build Multiplataforma - Estetica Lupatini
# Gera os executaveis para Android (APK), Windows Desktop (.exe) e Web Estatica
# ==============================================================================

param (
    [ValidateSet("all", "apk", "apk-split", "windows", "web")]
    [string]$Target = "all",

    [string]$SupabaseUrl = "",
    [string]$SupabaseAnonKey = ""
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Localiza dinamicamente a pasta frontend
if (Test-Path (Join-Path $ScriptDir "..\pubspec.yaml")) {
    $FrontendDir = (Resolve-Path (Join-Path $ScriptDir "..")).Path
} elseif (Test-Path (Join-Path $ScriptDir "..\frontend\pubspec.yaml")) {
    $FrontendDir = (Resolve-Path (Join-Path $ScriptDir "..\frontend")).Path
} else {
    $FrontendDir = (Get-Location).Path
}

Set-Location $FrontendDir

Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "  ESTETICA LUPATINI - AUTOMACAO DE BUILD MULTIPLATAFORMA        " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "Diretorio de trabalho: $(Get-Location)" -ForegroundColor Gray

# Argumentos de --dart-define caso sejam informados
$DartDefines = @()
if ($SupabaseUrl -ne "") {
    $DartDefines += "--dart-define=SUPABASE_URL=$SupabaseUrl"
}
if ($SupabaseAnonKey -ne "") {
    $DartDefines += "--dart-define=SUPABASE_ANON_KEY=$SupabaseAnonKey"
}

# 1. Pre-compilacao e validacao de dependencias
Write-Host ""
Write-Host "[1/4] Verificando dependencias e analise estatica..." -ForegroundColor Cyan
flutter pub get
flutter analyze --no-pub

# Funcao para compilar Web
function Build-Web {
    Write-Host ""
    Write-Host ">>> Compilando WEB (HTML / JS / CanvasKit / Wasm)..." -ForegroundColor Yellow
    $webArgs = @("build", "web", "--release", "--base-href", "/") + $DartDefines
    & flutter $webArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Build Web concluido com sucesso!" -ForegroundColor Green
        Write-Host "  Destino: $(Join-Path (Get-Location) 'build\web')" -ForegroundColor White
        Write-Host "  Pronto para deploy na Vercel, Netlify ou Firebase Hosting." -ForegroundColor Gray
    } else {
        Write-Error "Falha na compilacao do Web."
    }
}

# Funcao para compilar Windows Desktop
function Build-Windows {
    Write-Host ""
    Write-Host ">>> Compilando WINDOWS DESKTOP (x64 Release)..." -ForegroundColor Yellow
    $winArgs = @("build", "windows", "--release") + $DartDefines
    & flutter $winArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Build Windows concluido com sucesso!" -ForegroundColor Green
        $winReleaseDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"
        Write-Host "  Destino: $winReleaseDir" -ForegroundColor White
        Write-Host "  Executavel: $(Join-Path $winReleaseDir 'estetica_lupatini.exe')" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "[AVISO] Falha ao compilar para Windows Desktop nesta maquina." -ForegroundColor Red
        Write-Host "Causa: Visual Studio com a carga 'Desenvolvimento para Desktop com C++' nao encontrado." -ForegroundColor Yellow
        Write-Host "-> Opcao A: Instale o Visual Studio (https://visualstudio.microsoft.com/downloads/)." -ForegroundColor Gray
        Write-Host "-> Opcao B: Utilize o GitHub Actions (.github/workflows/build.yml) configurado no projeto para compilar na nuvem sem instalar nada!" -ForegroundColor Cyan
        exit 1
    }
}

# Funcao para compilar Android APK
function Build-Android {
    param([bool]$SplitAbi = $false)

    if ($SplitAbi) {
        Write-Host ""
        Write-Host ">>> Compilando ANDROID APK (Split per ABI)..." -ForegroundColor Yellow
        $apkArgs = @("build", "apk", "--release", "--split-per-abi") + $DartDefines
    } else {
        Write-Host ""
        Write-Host ">>> Compilando ANDROID APK (Universal Release)..." -ForegroundColor Yellow
        $apkArgs = @("build", "apk", "--release") + $DartDefines
    }

    & flutter $apkArgs
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] Build Android concluido com sucesso!" -ForegroundColor Green
        Write-Host "  Destino: $(Join-Path (Get-Location) 'build\app\outputs\flutter-apk')" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "[AVISO] Falha ao compilar o APK do Android nesta maquina." -ForegroundColor Red
        Write-Host "Causa: Android SDK nao encontrado localmente (variavel ANDROID_HOME nao definida)." -ForegroundColor Yellow
        Write-Host "-> Opcao A: Instale o Android Studio: https://developer.android.com/studio" -ForegroundColor Gray
        Write-Host "-> Opcao B: Utilize o GitHub Actions (.github/workflows/build.yml) para gerar o APK na nuvem!" -ForegroundColor Cyan
        exit 1
    }
}

# Execucao baseada no alvo
switch ($Target) {
    "web" {
        Build-Web
    }
    "windows" {
        Build-Windows
    }
    "apk" {
        Build-Android -SplitAbi $false
    }
    "apk-split" {
        Build-Android -SplitAbi $true
    }
    "all" {
        Build-Web
        Build-Windows
        Build-Android -SplitAbi $false
    }
}

Write-Host ""
Write-Host "=================================================================" -ForegroundColor DarkGreen
Write-Host "  TODOS OS BUILDS SOLICITADOS FORAM CONCLUIDOS COM SUCESSO!     " -ForegroundColor Green
Write-Host "=================================================================" -ForegroundColor DarkGreen
