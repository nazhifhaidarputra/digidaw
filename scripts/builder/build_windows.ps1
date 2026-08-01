$ErrorActionPreference = "Stop"

Write-Host "==> [Windows Build] Checking dependencies..." -ForegroundColor Cyan

# Ensure required CLI tools exist
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not installed or not in PATH. Aborting."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "Rust/Cargo is not installed or not in PATH. Aborting."
}

# Check for vcpkg (common way to manage C++ libs like rubberband on Windows)
$VCPKG_ROOT = $env:VCPKG_ROOT
if (-not $VCPKG_ROOT) {
    # Try to find it in common locations if not set in env
    if (Test-Path "$env:USERPROFILE\vcpkg\vcpkg.exe") {
        $VCPKG_ROOT = "$env:USERPROFILE\vcpkg"
    } elseif (Test-Path "C:\vcpkg\vcpkg.exe") {
        $VCPKG_ROOT = "C:\vcpkg"
    }
}

if ($VCPKG_ROOT -and (Test-Path "$VCPKG_ROOT\vcpkg.exe")) {
    Write-Host "==> [Windows Build] vcpkg found at $VCPKG_ROOT. Ensuring rubberband is installed..." -ForegroundColor Yellow
    & "$VCPKG_ROOT\vcpkg.exe" install rubberband:x64-windows
} else {
    Write-Host "==> [Windows Build] vcpkg not found. Skipping automatic rubberband installation." -ForegroundColor Yellow
    Write-Host "    If your build fails, please install rubberband via vcpkg or ensure the DLLs are in your PATH." -ForegroundColor Yellow
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

# Note: If rubberband.dll is not statically linked, you may need to copy it 
# into the $BuildDir before archiving so the app runs on other machines.
# Example: Copy-Item "$VCPKG_ROOT\installed\x64-windows\bin\rubberband.dll" -Destination $BuildDir -Force

Compress-Archive -Path "$BuildDir\*" -DestinationPath "$DistDir\Digidaw-windows-x64.zip" -Force

Write-Host "==> SUCCESS: Built $DistDir\Digidaw-windows-x64.zip" -ForegroundColor Green