$ErrorActionPreference = "Stop"

Write-Host "==> [Windows Build] Checking dependencies..." -ForegroundColor Cyan

# Ensure required CLI tools exist
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not installed or not in PATH. Aborting."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "Rust/Cargo is not installed or not in PATH. Aborting."
}

# Install FRB codegen if missing
if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing flutter_rust_bridge_codegen..." -ForegroundColor Yellow
    cargo install flutter_rust_bridge_codegen
}

Write-Host "==> [Windows Build] Running Flutter Rust Bridge Codegen..." -ForegroundColor Cyan
flutter_rust_bridge_codegen generate

Write-Host "==> [Windows Build] Fetching Flutter dependencies..." -ForegroundColor Cyan
flutter pub get

Write-Host "==> [Windows Build] Compiling Flutter Windows Release..." -ForegroundColor Cyan
flutter build windows --release

Write-Host "==> [Windows Build] Archiving Release Bundle..." -ForegroundColor Cyan
$BuildDir = "build\windows\x64\runner\Release"
$DistDir = "dist"

if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

Compress-Archive -Path "$BuildDir\*" -DestinationPath "$DistDir\Digidaw-windows-x64.zip" -Force

Write-Host "==> SUCCESS: Built $DistDir\Digidaw-windows-x64.zip" -ForegroundColor Green