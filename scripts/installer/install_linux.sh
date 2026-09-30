#!/usr/bin/env bash
# Installs DigiDAW from an extracted release archive for the current user.
#
# Installs the shared libraries the app links against through the system package manager
# (GTK 3, ALSA, FFTW, libsamplerate), copies the app to ~/.local/share/digidaw, and adds a
# `digidaw` launcher and a desktop menu entry. Rubber Band is linked into the app, so it is
# not installed here. build_linux.sh ships this script in the archive as install.sh, next to
# uninstall.sh, which stays in the install folder to remove the app later.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/digidaw"
BIN_DIR="$HOME/.local/bin"

if [ ! -x "$APP_DIR/karbeat" ]; then
    echo -e "\033[1;31m==> ERROR: Run this script from the extracted DigiDAW release folder.\033[0m"
    exit 1
fi

echo -e "\033[1;36m==> [DigiDAW Install] Installing runtime libraries...\033[0m"
if command -v apt-get >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Debian/Ubuntu. Installing packages via apt...\033[0m"
    sudo apt-get update
    sudo apt-get install -y libgtk-3-0 libasound2 libfftw3-double3 libsamplerate0
elif command -v dnf >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Fedora/RHEL. Installing packages via dnf...\033[0m"
    sudo dnf install -y gtk3 alsa-lib fftw-libs-double libsamplerate
elif command -v pacman >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected Arch Linux. Installing packages via pacman...\033[0m"
    sudo pacman -S --needed --noconfirm gtk3 alsa-lib fftw libsamplerate
elif command -v zypper >/dev/null 2>&1; then
    echo -e "\033[1;33m==> Detected openSUSE. Installing packages via zypper...\033[0m"
    sudo zypper install -y libgtk-3-0 libasound2 libfftw3-3 libsamplerate0
else
    echo -e "\033[1;33m==> WARNING: No supported package manager found (apt/dnf/pacman/zypper).\033[0m"
    echo -e "Please manually install GTK 3, ALSA, FFTW 3 (double precision), and libsamplerate."
fi

echo -e "\033[1;36m==> [DigiDAW Install] Copying app to $INSTALL_DIR...\033[0m"
rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR" "$BIN_DIR" "$DATA_HOME/applications"
cp -r "$APP_DIR/." "$INSTALL_DIR/"
rm -f "$INSTALL_DIR/install.sh"
ln -sf "$INSTALL_DIR/karbeat" "$BIN_DIR/digidaw"

cat > "$DATA_HOME/applications/digidaw.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=DigiDAW
Comment=Digital audio workstation
Exec=$INSTALL_DIR/karbeat
Categories=AudioVideo;Audio;
Terminal=false
EOF

if ldd "$INSTALL_DIR/karbeat" "$INSTALL_DIR"/lib/*.so | grep -q "not found"; then
    echo -e "\033[1;31m==> ERROR: Some libraries are still missing:\033[0m"
    ldd "$INSTALL_DIR/karbeat" "$INSTALL_DIR"/lib/*.so | grep "not found" | sort -u
    exit 1
fi

if ! command -v pipewire >/dev/null 2>&1 && ! command -v jackd >/dev/null 2>&1; then
    echo -e "\033[1;33m==> NOTE: Neither PipeWire nor JACK was found. Install one for low-latency audio.\033[0m"
fi

echo -e "\033[1;32m==> SUCCESS: DigiDAW is installed. Launch it from your app menu or run 'digidaw'.\033[0m"
echo "To uninstall, run: $INSTALL_DIR/uninstall.sh"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo -e "\033[1;33m==> NOTE: $BIN_DIR is not on your PATH; add it to run 'digidaw' from a terminal.\033[0m" ;;
esac
