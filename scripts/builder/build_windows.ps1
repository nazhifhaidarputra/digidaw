$ErrorActionPreference = "Stop"

# The paths below (rust\, build\, dist\) are relative to the repository root.
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
Set-Location $RepoRoot

# Windows PowerShell does not stop on a failing native command, so check each exit code.
function Assert-LastExitCode([string]$Step) {
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: $Step failed with exit code $LASTEXITCODE." -ForegroundColor Red
        exit $LASTEXITCODE
    }
}

Write-Host "==> [Windows Build] Checking dependencies..." -ForegroundColor Cyan

# Ensure required CLI tools exist
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "Flutter is not installed or not in PATH. Aborting."
}
if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
    Write-Error "Rust/Cargo is not installed or not in PATH. Aborting."
}
if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) {
    Write-Error "rustup is required to verify the Windows MSVC target. Install rustup and add it to PATH."
}

$vswherePath = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$hasMsvc = [bool](Get-Command cl.exe -ErrorAction SilentlyContinue)
if (-not $hasMsvc -and (Test-Path -LiteralPath $vswherePath)) {
    $visualStudioPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $hasMsvc = -not [string]::IsNullOrWhiteSpace($visualStudioPath)
}
if (-not $hasMsvc) {
    Write-Error "MSVC x64 build tools are required. Install Visual Studio Build Tools with 'Desktop development with C++'."
}

if (-not (Get-Command clang.exe -ErrorAction SilentlyContinue)) {
    Write-Error "LLVM/Clang is required by CPAL's ASIO bindings. Install LLVM and add clang.exe to PATH."
}

$libclangCandidates = @()
if ($env:LIBCLANG_PATH) {
    $libclangCandidates += (Join-Path $env:LIBCLANG_PATH "libclang.dll")
}
$clangCommand = Get-Command clang.exe -ErrorAction SilentlyContinue
if ($clangCommand) {
    $libclangCandidates += (Join-Path (Split-Path -Parent $clangCommand.Source) "libclang.dll")
    $libclangCandidates += (Join-Path (Split-Path -Parent (Split-Path -Parent $clangCommand.Source)) "bin\libclang.dll")
}
if (-not ($libclangCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)) {
    Write-Error "libclang.dll was not found. Set LIBCLANG_PATH to the LLVM bin directory before building ASIO support."
}

$installedRustTargets = rustup target list --installed
if ($LASTEXITCODE -ne 0 -or $installedRustTargets -notcontains "x86_64-pc-windows-msvc") {
    Write-Error "Rust target x86_64-pc-windows-msvc is required. Run: rustup target add x86_64-pc-windows-msvc"
}

# Rubber Band comes from vcpkg (see rust/vcpkg.json)
$VCPKG_ROOT = $env:VCPKG_ROOT
if (-not $VCPKG_ROOT) {
    # Try to find it in common locations if not set in env
    $vcpkgCommand = Get-Command vcpkg.exe -ErrorAction SilentlyContinue
    if (Test-Path "$env:USERPROFILE\vcpkg\vcpkg.exe") {
        $VCPKG_ROOT = "$env:USERPROFILE\vcpkg"
    } elseif (Test-Path "C:\vcpkg\vcpkg.exe") {
        $VCPKG_ROOT = "C:\vcpkg"
    } elseif ($vcpkgCommand) {
        $VCPKG_ROOT = Split-Path -Parent $vcpkgCommand.Source
    }
}
if (-not ($VCPKG_ROOT -and (Test-Path "$VCPKG_ROOT\vcpkg.exe"))) {
    Write-Error "vcpkg is required to build Rubber Band. Install vcpkg and set VCPKG_ROOT."
}

# karbeat-rb/build.rs links and generates bindings from rust\vcpkg_installed\x64-windows, so
# install the manifest in rust\vcpkg.json there (not into vcpkg's classic-mode tree).
Write-Host "==> [Windows Build] Installing rubberband with vcpkg ($VCPKG_ROOT)..." -ForegroundColor Cyan
$RustDir = Join-Path $RepoRoot "rust"
& "$VCPKG_ROOT\vcpkg.exe" install --triplet x64-windows "--x-manifest-root=$RustDir" "--x-install-root=$RustDir\vcpkg_installed"
Assert-LastExitCode "vcpkg install"

# Install FRB codegen if missing. Keep it on the same version as the flutter_rust_bridge crate.
$FrbVersion = "2.12.0"
if (-not (Get-Command flutter_rust_bridge_codegen -ErrorAction SilentlyContinue)) {
    Write-Host "==> Installing flutter_rust_bridge_codegen $FrbVersion..." -ForegroundColor Yellow
    cargo install flutter_rust_bridge_codegen --version $FrbVersion --locked
    Assert-LastExitCode "cargo install flutter_rust_bridge_codegen"
}

Write-Host "==> [Windows Build] Running Flutter Rust Bridge Codegen..." -ForegroundColor Cyan
flutter_rust_bridge_codegen generate
Assert-LastExitCode "flutter_rust_bridge_codegen generate"

Write-Host "==> [Windows Build] Fetching Flutter dependencies..." -ForegroundColor Cyan
flutter pub get
Assert-LastExitCode "flutter pub get"

Write-Host "==> [Windows Build] Fetching tempo detection models..." -ForegroundColor Cyan
# Pinned to the same files as scripts/fetch_beat_models.sh; mel_spectrogram.onnx is committed.
# The small beat model; the FP32 model is no longer used.
$SmallModel = Join-Path $PSScriptRoot "..\..\assets\models\beat_this_small.onnx"
$SmallSha256 = "a5f8d39d989f31859454ba27afe61c5317ca95e4d9373e6853e5361b8937172f"
if (-not (Test-Path $SmallModel) -or (Get-FileHash $SmallModel -Algorithm SHA256).Hash.ToLower() -ne $SmallSha256) {
    Invoke-WebRequest -Uri "https://raw.githubusercontent.com/danigb/beat-this-rs/089b509247e6fdcec666511c0dcf0d5f39c21e73/models/beat_this_small.onnx" -OutFile $SmallModel
    if ((Get-FileHash $SmallModel -Algorithm SHA256).Hash.ToLower() -ne $SmallSha256) {
        Remove-Item $SmallModel
        Write-Host "ERROR: beat_this_small.onnx checksum mismatch." -ForegroundColor Red
        exit 1
    }
}

Write-Host "==> [Windows Build] Compiling Flutter Windows Release..." -ForegroundColor Cyan
flutter build windows --release
Assert-LastExitCode "flutter build windows"

Write-Host "==> [Windows Build] Archiving Release Bundle..." -ForegroundColor Cyan
$BuildDir = "build\windows\x64\runner\Release"
$DistDir = "dist"
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

# The vcpkg DLLs (rubberband and its dependencies) are installed next to the exe by
# windows/CMakeLists.txt.

Compress-Archive -Path "$BuildDir\*" -DestinationPath "$DistDir\Digidaw-windows-x64.zip" -Force

Write-Host "==> SUCCESS: Built $DistDir\Digidaw-windows-x64.zip" -ForegroundColor Green
