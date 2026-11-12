# Builds the Windows release and packages it into dist\:
#
#   digidaw-<version>-windows-x64-setup.exe   installer into Program Files\DigiDAW
#   digidaw-<version>-windows-x64.zip         the same bundle, to run without installing
#
# each with a .sha256 next to it. The bundle carries the Visual C++ runtime DLLs, so it runs on a
# Windows without the Visual C++ Redistributable. The installer needs Inno Setup 6; without it only
# the zip is built, unless -RequireInstaller is given (as the release workflow does).
param(
    [switch]$RequireInstaller
)

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

$BuildDir = Join-Path $RepoRoot "build\windows\x64\runner\Release"
$DistDir = Join-Path $RepoRoot "dist"
if (-not (Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir | Out-Null
}

# The vcpkg DLLs (rubberband and its dependencies) are installed next to the exe by
# windows/runner/CMakeLists.txt. The Visual C++ runtime is added here, app-locally, from the
# redistributable folder of the Visual Studio that built the app, so the versions match.
Write-Host "==> [Windows Build] Bundling the Visual C++ runtime..." -ForegroundColor Cyan
$RedistRoot = $env:VCToolsRedistDir
if (-not $RedistRoot -and (Test-Path -LiteralPath $vswherePath)) {
    $visualStudioPath = & $vswherePath -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    $msvcRedist = Join-Path $visualStudioPath "VC\Redist\MSVC"
    if (Test-Path -LiteralPath $msvcRedist) {
        $RedistRoot = Get-ChildItem -LiteralPath $msvcRedist -Directory |
            Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
            Sort-Object { [version]$_.Name } -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}
$CrtDir = if ($RedistRoot) {
    Get-ChildItem -LiteralPath (Join-Path $RedistRoot "x64") -Directory -Filter "Microsoft.VC*.CRT" -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if (-not $CrtDir) {
    Write-Error "The Visual C++ runtime redistributable (x64\Microsoft.VC*.CRT) was not found. Install the MSVC build tools with Visual Studio."
}
Copy-Item -Path (Join-Path $CrtDir "*.dll") -Destination $BuildDir -Force
Write-Host "    Copied the runtime from $CrtDir"

$Version = (Select-String -Path (Join-Path $RepoRoot "pubspec.yaml") -Pattern '^version:\s*([^\s+]+)').Matches[0].Groups[1].Value
if (-not $Version) {
    Write-Error "Could not read the version from pubspec.yaml."
}

# Writes a checksum in the format `sha256sum -c` reads, without a BOM or CRLF.
function Write-Checksum([string]$File) {
    $hash = (Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLower()
    $name = Split-Path -Leaf $File
    [IO.File]::WriteAllText("$File.sha256", "$hash  $name`n")
}

Get-ChildItem -LiteralPath $DistDir -Filter "digidaw-*-windows-x64*" | Remove-Item -Force

Write-Host "==> [Windows Build] Archiving Release Bundle..." -ForegroundColor Cyan
$Archive = Join-Path $DistDir "digidaw-$Version-windows-x64.zip"
Compress-Archive -Path "$BuildDir\*" -DestinationPath $Archive -Force
Write-Checksum $Archive

Write-Host "==> [Windows Build] Building the installer..." -ForegroundColor Cyan
$Iscc = (Get-Command ISCC.exe -ErrorAction SilentlyContinue).Source
if (-not $Iscc) {
    $Iscc = @(
        (Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"),
        (Join-Path $env:ProgramFiles "Inno Setup 6\ISCC.exe")
    ) | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}
if ($Iscc) {
    & $Iscc "/DAppVersion=$Version" "/DBundleDir=$BuildDir" "/DOutputDir=$DistDir" (Join-Path $RepoRoot "scripts\installer\digidaw.iss")
    Assert-LastExitCode "Inno Setup"
    $Installer = Join-Path $DistDir "digidaw-$Version-windows-x64-setup.exe"
    Write-Checksum $Installer
    Write-Host "==> SUCCESS: Built $Installer" -ForegroundColor Green
} elseif ($RequireInstaller) {
    Write-Error "Inno Setup 6 (ISCC.exe) is required to build the installer."
} else {
    Write-Host "WARNING: Inno Setup 6 was not found, so no installer was built. Install it from https://jrsoftware.org/isdl.php." -ForegroundColor Yellow
}

Write-Host "==> SUCCESS: Built $Archive" -ForegroundColor Green
