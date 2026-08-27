#!/usr/bin/env bash
set -e

echo -e "\033[1;36m==> [Android Build] Checking environment...\033[0m"

# Check for Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo -e "\033[1;31m==> ERROR: ANDROID_HOME or ANDROID_SDK_ROOT is not set.\033[0m"
    echo "Please set it to your Android SDK path (e.g., ~/Android/Sdk)."
    exit 1
fi

SDK_PATH=${ANDROID_HOME:-$ANDROID_SDK_ROOT}

# Check for NDK
NDK_PATH="$SDK_PATH/ndk-bundle"
if [ ! -d "$NDK_PATH" ]; then
    # Try to find a specific version if ndk-bundle doesn't exist
    NDK_PATH=$(find "$SDK_PATH/ndk" -maxdepth 1 -type d | sort | tail -n 1)
    if [ -z "$NDK_PATH" ]; then
        echo -e "\033[1;31m==> ERROR: Android NDK not found.\033[0m"
        echo "Please install the NDK via Android Studio SDK Manager."
        exit 1
    fi
fi
echo -e "Found NDK at: $NDK_PATH"

echo -e "\033[1;36m==> [Android Build] Checking system dependencies for host...\033[0m"

# Distro-agnostic dependency installation (Host build tools only)
DEPS_INSTALLED=false
if command -v apt-get >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Debian/Ubuntu. Installing packages via apt...\033[0m"
    sudo apt-get update
    sudo apt-get install -y git clang cmake ninja-build pkg-config
    DEPS_INSTALLED=true
elif command -v dnf >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Fedora/RHEL. Installing packages via dnf...\033[0m"
    sudo dnf install -y git clang cmake ninja-build pkgconf-pkg-config
    DEPS_INSTALLED=true
elif command -v pacman >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Arch Linux. Installing packages via pacman...\033[0m"
    sudo pacman -Sy --noconfirm git clang cmake ninja pkgconf
    DEPS_INSTALLED=true
elif command -v zypper >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected openSUSE. Installing packages via zypper...\033[0m"
    sudo zypper install -y git clang cmake ninja pkg-config
    DEPS_INSTALLED=true
else
    echo -e "\033[1;33m==> No supported package manager found (apt/dnf/pacman/zypper).\033[0m"
    echo -e "Please manually ensure the following are installed: git, clang, cmake, ninja, pkg-config."
fi

if [ "$DEPS_INSTALLED" = false ]; then
    echo -e "\033[1;33m==> WARNING: Automatic dependency installation was skipped.\033[0m"
fi

# Ensure required CLI tools exist
command -v flutter >/dev/null 2>&1 || { echo "Flutter is not installed. Aborting."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Rust/Cargo is not installed. Aborting."; exit 1; }

# Install FRB codegen if missing
if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Installing flutter_rust_bridge_codegen...\033[0m"
    cargo install flutter_rust_bridge_codegen
fi

# Add Android targets to Rust
echo -e "\033[1;36m==> [Android Build] Adding Rust Android targets...\033[0m"
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android

# =========================================================================================
# CROSS-COMPILE RUBBER BAND FOR ANDROID
# =========================================================================================
echo -e "\033[1;36m==> [Android Build] Cross-compiling Rubber Band library...\033[0m"
RUBBERBAND_DIR="rubberband_src"
if [ ! -d "$RUBBERBAND_DIR" ]; then
    git clone https://github.com/breakfastquay/rubberband.git "$RUBBERBAND_DIR"
fi

# We build strictly for arm64-v8a here, aligning with the flutter build target below
mkdir -p "$RUBBERBAND_DIR/build-android-arm64"
pushd "$RUBBERBAND_DIR/build-android-arm64" > /dev/null

cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$NDK_PATH/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="arm64-v8a" \
    -DANDROID_PLATFORM=android-21 \
    -DBUILD_SHARED_LIBS=ON \
    -G Ninja

ninja
popd > /dev/null

# Copy the compiled shared library to the Flutter Android jniLibs folder so it gets bundled
JNI_DIR="android/app/src/main/jniLibs/arm64-v8a"
mkdir -p "$JNI_DIR"
cp "$RUBBERBAND_DIR/build-android-arm64/librubberband.so" "$JNI_DIR/"
echo -e "\033[1;32m==> Rubber Band compiled and injected into $JNI_DIR\033[0m"
# =========================================================================================

echo -e "\033[1;36m==> [Android Build] Running Flutter Rust Bridge Codegen...\033[0m"
flutter_rust_bridge_codegen generate

echo -e "\033[1;36m==> [Android Build] Fetching Flutter dependencies...\033[0m"
flutter pub get

echo -e "\033[1;36m==> [Android Build] Compiling Flutter Android Release (APK)...\033[0m"
# You can also use --aab for App Bundle if publishing to Play Store
flutter build apk --release --target-platform android-arm64

echo -e "\033[1;36m==> [Android Build] Archiving Release...\033[0m"
BUILD_DIR="build/app/outputs/flutter-apk"
DIST_DIR="dist"
mkdir -p "$DIST_DIR"

# Copy the APK to dist
cp "$BUILD_DIR/app-release.apk" "$DIST_DIR/Digidaw-android-arm64.apk"

echo -e "\033[1;32m==> SUCCESS: Built $DIST_DIR/Digidaw-android-arm64.apk\033[0m"