#!/usr/bin/env bash
set -e

echo -e "\033[1;36m==> [Linux Build] Checking required audio backends...\033[0m"
# Check for JACK or Pipewire
HAS_JACK=false
HAS_PIPEWIRE=false
if command -v jackd >/dev/null 2>&1; then
    echo -e "Found JACK: $(jackd -V | head -n 1)"
    HAS_JACK=true
fi
if command -v pipewire >/dev/null 2>&1; then
    echo -e "Found PipeWire: $(pipewire --version | head -n 1)"
    HAS_PIPEWIRE=true
fi

if [ "$HAS_JACK" = false ] && [ "$HAS_PIPEWIRE" = false ]; then
    echo -e "\033[1;31m==> ERROR: Neither JACK nor PipeWire was found on this system.\033[0m"
    echo -e "Please install either JACK or PipeWire to build and run this DAW."
    exit 1
fi

echo -e "\033[1;36m==> [Linux Build] Checking system dependencies...\033[0m"

# Distro-agnostic dependency installation
DEPS_INSTALLED=false
if command -v apt-get >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Debian/Ubuntu. Installing packages via apt...\033[0m"
    sudo apt-get update
    sudo apt-get install -y clang cmake ninja-build meson pkg-config libgtk-3-dev libasound2-dev libjack-jackd2-dev librubberband-dev libfftw3-dev libsamplerate0-dev
    DEPS_INSTALLED=true
elif command -v dnf >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Fedora/RHEL. Installing packages via dnf...\033[0m"
    sudo dnf install -y clang cmake ninja-build meson pkgconf-pkg-config gtk3-devel alsa-lib-devel jack-audio-connection-kit-devel rubberband-devel fftw-devel libsamplerate-devel
    DEPS_INSTALLED=true
elif command -v pacman >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Arch Linux. Installing packages via pacman...\033[0m"
    sudo pacman -Sy --noconfirm clang cmake ninja meson pkgconf gtk3 alsa-lib jack2 rubberband fftw libsamplerate
    DEPS_INSTALLED=true
elif command -v zypper >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected openSUSE. Installing packages via zypper...\033[0m"
    sudo zypper install -y clang cmake ninja meson pkg-config gtk3-devel alsa-devel jack-devel librubberband-devel fftw3-devel libsamplerate-devel
    DEPS_INSTALLED=true
else
    echo -e "\033[1;33m==> No supported package manager found (apt/dnf/pacman/zypper).\033[0m"
    echo -e "Please manually ensure the following are installed: clang, cmake, ninja, meson, pkg-config, GTK3, ALSA, JACK, RubberBand, FFTW, and libsamplerate development libraries."
fi

if [ "$DEPS_INSTALLED" = false ]; then
    echo -e "\033[1;33m==> WARNING: Automatic dependency installation was skipped.\033[0m"
fi

# Ensure required CLI tools exist
command -v flutter >/dev/null 2>&1 || { echo "Flutter is not installed. Aborting."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Rust/Cargo is not installed. Aborting."; exit 1; }
command -v meson >/dev/null 2>&1 || { echo "Meson is not installed. Aborting."; exit 1; }

# Install FRB codegen if missing
if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Installing flutter_rust_bridge_codegen...\033[0m"
    # Keep in step with the flutter_rust_bridge runtime pinned in pubspec.yaml and karbeat-flutter-ffi.
    cargo install flutter_rust_bridge_codegen --version 2.12.0 --locked
fi

# Rubber Band is linked statically so the released app runs without it installed: many
# distributions do not package 4.0 yet. It is built from source because distributions only
# ship it as a shared library. FFTW and libsamplerate stay dynamic; install.sh installs them.
RUBBERBAND_VERSION="4.0.0"
RUBBERBAND_SHA256="af050313ee63bc18b35b2e064e5dce05b276aaf6d1aa2b8a82ced1fe2f8028e9"
RUBBERBAND_DIR="build/rubberband"
RUBBERBAND_PREFIX="$PWD/$RUBBERBAND_DIR/install-$RUBBERBAND_VERSION-fftw"
if [ ! -f "$RUBBERBAND_PREFIX/lib/librubberband.a" ]; then
    echo -e "\033[1;36m==> [Linux Build] Building static Rubber Band $RUBBERBAND_VERSION...\033[0m"
    mkdir -p "$RUBBERBAND_DIR"
    RUBBERBAND_ARCHIVE="$RUBBERBAND_DIR/rubberband-$RUBBERBAND_VERSION.tar.bz2"
    curl -fL --retry 3 -o "$RUBBERBAND_ARCHIVE" \
        "https://breakfastquay.com/files/releases/rubberband-$RUBBERBAND_VERSION.tar.bz2"
    echo "$RUBBERBAND_SHA256  $RUBBERBAND_ARCHIVE" | sha256sum -c -
    rm -rf "$RUBBERBAND_DIR/rubberband-$RUBBERBAND_VERSION" "$RUBBERBAND_DIR/build"
    tar -xjf "$RUBBERBAND_ARCHIVE" -C "$RUBBERBAND_DIR"
    meson setup "$RUBBERBAND_DIR/build" "$RUBBERBAND_DIR/rubberband-$RUBBERBAND_VERSION" \
        --prefix="$RUBBERBAND_PREFIX" --libdir=lib --buildtype=release \
        -Ddefault_library=static -Dfft=fftw -Dresampler=libsamplerate \
        -Djni=disabled -Dladspa=disabled -Dvamp=disabled -Dcmdline=disabled -Dtests=disabled
    ninja -C "$RUBBERBAND_DIR/build" install
fi
export PKG_CONFIG_PATH="$RUBBERBAND_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
# Ask for the static archive explicitly: the system library folder also ends up on the link
# line (for FFTW and libsamplerate), and a distro librubberband.so there would otherwise win.
export RUBBERBAND_STATIC=1

echo -e "\033[1;36m==> [Linux Build] Running Flutter Rust Bridge Codegen...\033[0m"
flutter_rust_bridge_codegen generate

echo -e "\033[1;36m==> [Linux Build] Fetching tempo detection models...\033[0m"
"$(dirname "$0")/../fetch_beat_models.sh"

echo -e "\033[1;36m==> [Linux Build] Fetching Flutter dependencies...\033[0m"
flutter pub get

echo -e "\033[1;36m==> [Linux Build] Compiling Flutter Linux Release...\033[0m"
flutter build linux --release

echo -e "\033[1;36m==> [Linux Build] Archiving Release Bundle...\033[0m"
BUILD_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"
mkdir -p "$DIST_DIR"
if ldd "$BUILD_DIR/lib/libkarbeat_flutter_ffi.so" | grep -q librubberband; then
    echo -e "\033[1;31m==> ERROR: The bundle links a shared Rubber Band instead of the static one.\033[0m"
    exit 1
fi
cp "$(dirname "$0")/../installer/install_linux.sh" "$BUILD_DIR/install.sh"
cp "$(dirname "$0")/../installer/uninstall_linux.sh" "$BUILD_DIR/uninstall.sh"
tar -czvf "$DIST_DIR/Digidaw-linux-x64.tar.gz" -C "$BUILD_DIR" .

echo -e "\033[1;32m==> SUCCESS: Built $DIST_DIR/Digidaw-linux-x64.tar.gz\033[0m"