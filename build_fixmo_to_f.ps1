# Build FixMo release APK using F:\dart_define.env (fallback: MAU Municipality folder).
# Copies APK to F:\FixMo-release-<timestamp>.apk and F:\FixMo-release.apk

$ErrorActionPreference = 'Stop'
# Prefer dart_define.env on F:\ root; fallback to MAU Municipality folder
$FRoot = 'F:\'
$FEnvPrimary = Join-Path $FRoot 'dart_define.env'
$FEnvFallback = 'F:\Ddrive\AI\MAU Municipality\dart_define.env'
$AppDir = Join-Path $PSScriptRoot 'frontend\fixmo_app'
$WorkEnv = Join-Path $AppDir 'dart_define.env'

if (-not (Test-Path $AppDir)) {
    Write-Error "Flutter app not found at $AppDir"
}

if (Test-Path $FEnvPrimary) {
    Copy-Item $FEnvPrimary $WorkEnv -Force
    Write-Host "Copied $FEnvPrimary -> $WorkEnv"
} elseif (Test-Path $FEnvFallback) {
    Copy-Item $FEnvFallback $WorkEnv -Force
    Write-Host "Copied $FEnvFallback -> $WorkEnv"
} else {
    Write-Warning "No dart_define.env on F:\ or MAU folder — using existing $WorkEnv"
}

Push-Location $AppDir
try {
    flutter build apk --dart-define-from-file=dart_define.env
} finally {
    Pop-Location
}

$apk = Join-Path $AppDir 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Error "APK not found at $apk"
}

$dest = Join-Path $FRoot ('FixMo-release-{0}.apk' -f (Get-Date -Format 'yyyyMMdd-HHmm'))
# Also write latest as F:\FixMo-release.apk
$destLatest = Join-Path $FRoot 'FixMo-release.apk'
Copy-Item $apk $dest -Force
Copy-Item $apk $destLatest -Force
Write-Host "APK -> $dest"
Write-Host "APK -> $destLatest"
