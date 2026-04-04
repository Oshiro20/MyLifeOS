# MyLifeOS — Script de Build Release
# Genera APKs split por ABI (arm64, armeabi-v7a, x86_64) y los organiza en releases/
# Uso: .\build_release.ps1

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleasesDir = Join-Path $ProjectRoot "releases"

Write-Host "🚀 MyLifeOS Release Build" -ForegroundColor Cyan
Write-Host "================================" -ForegroundColor Cyan

# Limpiar artifacts anteriores
if (Test-Path $ReleasesDir) {
    Write-Host "🧹 Limpiando releases anteriores..." -ForegroundColor Yellow
    Remove-Item -Recurse -Force $ReleasesDir
}
New-Item -ItemType Directory -Path $ReleasesDir | Out-Null

# Build APK split por ABI
Write-Host "⚙️  Compilando APKs (split per ABI)..." -ForegroundColor Yellow
& flutter build apk --split-per-abi --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build fallido. Revisa los errores arriba." -ForegroundColor Red
    exit 1
}

# Copiar APKs al directorio releases/
$ApkDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"
$Abis = @("arm64-v8a", "armeabi-v7a", "x86_64")

foreach ($abi in $Abis) {
    $src = Join-Path $ApkDir "app-$abi-release.apk"
    $dst = Join-Path $ReleasesDir "MyLifeOS-$abi.apk"
    if (Test-Path $src) {
        Copy-Item $src $dst
        $size = [math]::Round((Get-Item $dst).Length / 1MB, 1)
        Write-Host "  ✅ MyLifeOS-$abi.apk  ($size MB)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "✨ APKs generados en: $ReleasesDir" -ForegroundColor Cyan
Write-Host "   Instala el APK correcto según tu dispositivo:" -ForegroundColor Gray
Write-Host "   • arm64-v8a  → La mayoría de teléfonos modernos (Samsung, Pixel, OnePlus)" -ForegroundColor Gray
Write-Host "   • armeabi-v7a → Teléfonos antiguos (32-bit)" -ForegroundColor Gray
Write-Host "   • x86_64     → Emuladores Android Studio" -ForegroundColor Gray
