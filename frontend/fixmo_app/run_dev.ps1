# FixMo dev runner -- reads .env and passes values as --dart-define
# Usage: .\run_dev.ps1 [extra flutter args]

$envFile = Join-Path $PSScriptRoot ".env"
if (-not (Test-Path $envFile)) {
    Write-Error ".env file not found. Copy .env.example to .env and fill in your values."
    exit 1
}

$defines = @()
Get-Content $envFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#")) {
        $parts = $line -split "=", 2
        if ($parts.Length -eq 2) {
            $defines += "--dart-define=$($parts[0].Trim())=$($parts[1].Trim())"
        }
    }
}

Write-Host "Running flutter with $($defines.Count) dart-define(s)..."
flutter run @defines @args
