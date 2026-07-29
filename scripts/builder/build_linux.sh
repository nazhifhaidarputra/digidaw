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

# Install Linux system dependencies for Flutter and Rust Audio (JACK/ALSA)
if command -v apt-get >/dev/null 2>&1; then
  echo -e "\033[1;33m==> Installing required apt packages (you may be prompted for sudo password)...\033[0m"
  sudo apt-get update
  sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libasound2-dev libjack-jackd2-dev
else
  echo -e "\033[1;33m==> 'apt-get' not found (Not Debian/Ubuntu). Please ensure GTK3, ALSA, and JACK development headers are installed manually.\033[0m"
fi

# Ensure required CLI tools exist
command -v flutter >/dev/null 2>&1 || { echo "Flutter is not installed. Aborting."; exit 1; }
command -v cargo >/dev/null 2>&1 || { echo "Rust/Cargo is not installed. Aborting."; exit 1; }

# Install FRB codegen if missing
if ! command -v flutter_rust_bridge_codegen >/dev/null 2>&1; then
  echo -e "\033[1;33m==> Installing flutter_rust_bridge_codegen...\033[0m"
  cargo install flutter_rust_bridge_codegen
fi

echo -e "\033[1;36m==> [Linux Build] Running Flutter Rust Bridge Codegen...\033[0m"
flutter_rust_bridge_codegen generate

echo -e "\033[1;36m==> [Linux Build] Fetching Flutter dependencies...\033[0m"
flutter pub get

echo -e "\033[1;36m==> [Linux Build] Compiling Flutter Linux Release...\033[0m"
flutter build linux --release

echo -e "\033[1;36m==> [Linux Build] Archiving Release Bundle...\033[0m"
BUILD_DIR="build/linux/x64/release/bundle"
DIST_DIR="dist"

mkdir -p "$DIST_DIR"
tar -czvf "$DIST_DIR/Digidaw-linux-x64.tar.gz" -C "$BUILD_DIR" .

echo -e "\033[1;32m==> SUCCESS: Built $DIST_DIR/Digidaw-linux-x64.tar.gz\033[0m"