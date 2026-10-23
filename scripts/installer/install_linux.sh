#!/usr/bin/env bash
# Installs DigiDAW from an extracted release archive for the current user.
#
# Installs the shared libraries the app links against through the system package manager
# (GTK 3, ALSA, FFTW, libsamplerate, lilv), copies the app to ~/.local/share/digidaw, and adds a
# `digidaw` launcher and a desktop menu entry with its icon. Rubber Band is linked into the app, so it is
# not installed here. build_linux.sh ships this script in the archive as install.sh, next to
# uninstall.sh, which stays in the install folder to remove the app later.
set -euo pipefail

APP_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/digidaw"
BIN_DIR="$HOME/.local/bin"
APP_ID="app.digidaw.Digidaw"
ICON_DIR="$DATA_HOME/icons/hicolor/256x256/apps"
ICON_SOURCE="$APP_DIR/data/app_icon.png"

have() { command -v "$1" >/dev/null 2>&1; }
warn() { echo -e "\033[1;33m==> WARNING: $*\033[0m"; }
error() { echo -e "\033[1;31m==> ERROR: $*\033[0m"; }

if [ ! -x "$APP_DIR/karbeat" ]; then
    error "Run this script from the extracted DigiDAW release folder."
    exit 1
fi

ARCH="$(uname -m)"
case "$ARCH" in
    x86_64 | amd64) ;;
    *)
        error "This release is for x86_64 Linux; this machine is $ARCH."
        exit 1
        ;;
esac

# Package managers are run through sudo when the script is not already root.
SUDO=()
CAN_INSTALL=true
if [ "$(id -u)" -ne 0 ]; then
    if have sudo; then
        SUDO=(sudo)
    else
        CAN_INSTALL=false
    fi
fi
run_root() {
    if [ "${#SUDO[@]}" -gt 0 ]; then
        "${SUDO[@]}" "$@"
    else
        "$@"
    fi
}

# Prefer the distribution declared in os-release: a system can have more than
# one package manager installed, and the package names differ between them.
DISTRO_ID=""
DISTRO_LIKE=""
if [ -r /etc/os-release ]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    DISTRO_ID="${ID:-}"
    DISTRO_LIKE="${ID_LIKE:-}"
fi
DISTRO_ID="$(printf '%s' "$DISTRO_ID" | tr '[:upper:]' '[:lower:]')"
DISTRO_KEYS=" $(printf '%s %s' "$DISTRO_ID" "$DISTRO_LIKE" | tr '[:upper:]' '[:lower:]') "

PKG_MANAGER=""
case "$DISTRO_KEYS" in
    *debian* | *ubuntu*) PKG_MANAGER="apt-get" ;;
    *arch* | *manjaro* | *endeavouros* | *cachyos* | *garuda*) PKG_MANAGER="pacman" ;;
    *fedora* | *rhel* | *centos* | *almalinux* | *rocky* | *nobara* | *bazzite* | *" ol "*) PKG_MANAGER="dnf" ;;
    *suse*) PKG_MANAGER="zypper" ;;
esac
if [ -n "$PKG_MANAGER" ] && ! have "$PKG_MANAGER"; then
    PKG_MANAGER=""
fi
if [ -z "$PKG_MANAGER" ]; then
    for candidate in apt-get dnf pacman zypper; do
        if have "$candidate"; then
            PKG_MANAGER="$candidate"
            break
        fi
    done
fi

INSTALL_FAILED=false
if [ "$CAN_INSTALL" = false ]; then
    warn "sudo is not available and this script is not running as root; skipping automatic library installation."
    INSTALL_FAILED=true
fi

echo -e "\033[1;36m==> [DigiDAW Install] Installing runtime libraries...\033[0m"
case "$PKG_MANAGER" in
    apt-get)
        echo -e "\033[1;33m==> Detected Debian/Ubuntu (apt).\033[0m"
        if [ "$INSTALL_FAILED" = false ]; then
            if ! run_root apt-get update; then
                warn "Could not refresh the apt package lists; using the cached lists."
            fi
            # GTK 3 and ALSA were renamed for the 64-bit time_t transition in
            # Ubuntu 24.04+ and Debian 13+. Install whichever names exist. Look
            # this up after apt-get update, since a fresh system has no lists.
            if have apt-cache && apt-cache show libasound2t64 >/dev/null 2>&1; then
                APT_PACKAGES=(libgtk-3-0t64 libasound2t64)
            else
                APT_PACKAGES=(libgtk-3-0 libasound2)
            fi
            APT_PACKAGES+=(libfftw3-double3 libsamplerate0 liblilv-0-0)
            if ! run_root apt-get install -y "${APT_PACKAGES[@]}"; then
                INSTALL_FAILED=true
            fi
        fi
        ;;
    dnf)
        echo -e "\033[1;33m==> Detected Fedora/RHEL (dnf).\033[0m"
        if [ -e /run/ostree-booted ]; then
            warn "This is an immutable Fedora system; packages cannot be installed with dnf."
            echo "Layer the runtime libraries, reboot, then run this installer again:"
            echo "  sudo rpm-ostree install gtk3 alsa-lib fftw-libs-double libsamplerate lilv-libs"
            INSTALL_FAILED=true
        elif [ "$INSTALL_FAILED" = false ]; then
            DNF_PACKAGES=(gtk3 alsa-lib fftw-libs-double libsamplerate)
            case "$DISTRO_ID" in
                rhel | centos | almalinux | rocky | ol)
                    # lilv is only packaged in EPEL on RHEL and its rebuilds.
                    if ! rpm -q lilv-libs >/dev/null 2>&1 &&
                        ! run_root dnf -q list --available lilv-libs >/dev/null 2>&1; then
                        warn "lilv-libs is not in the enabled repositories; it is packaged in EPEL."
                        echo "Enable EPEL and run this installer again, for example:"
                        echo "  sudo dnf install epel-release"
                    else
                        DNF_PACKAGES+=(lilv-libs)
                    fi
                    ;;
                *)
                    DNF_PACKAGES+=(lilv-libs)
                    ;;
            esac
            if ! run_root dnf install -y "${DNF_PACKAGES[@]}"; then
                INSTALL_FAILED=true
            fi
        fi
        ;;
    pacman)
        echo -e "\033[1;33m==> Detected Arch Linux (pacman).\033[0m"
        if [ "$INSTALL_FAILED" = false ]; then
            # A fresh system can have no synced databases. Syncing them once is
            # safe; running -Sy before every install risks a partial upgrade, so
            # an existing database is used as-is.
            if ! compgen -G "/var/lib/pacman/sync/*.db" >/dev/null; then
                if ! run_root pacman -Sy --noconfirm; then
                    warn "Could not sync the pacman package databases."
                    INSTALL_FAILED=true
                fi
            fi
            if [ "$INSTALL_FAILED" = false ] &&
                ! run_root pacman -S --needed --noconfirm gtk3 alsa-lib fftw libsamplerate lilv; then
                warn "If pacman failed because its database is stale, run 'sudo pacman -Syu' and retry."
                INSTALL_FAILED=true
            fi
        fi
        ;;
    zypper)
        echo -e "\033[1;33m==> Detected openSUSE (zypper).\033[0m"
        if [ "$INSTALL_FAILED" = false ]; then
            if ! run_root zypper --non-interactive install -y \
                libgtk-3-0 libasound2 libfftw3-3 libsamplerate0 liblilv-0-0; then
                INSTALL_FAILED=true
            fi
        fi
        ;;
    *)
        warn "No supported package manager found (apt, dnf, pacman, zypper)."
        echo "Install GTK 3, ALSA, FFTW 3 (double precision), libsamplerate, and lilv manually."
        INSTALL_FAILED=true
        ;;
esac

if [ "$INSTALL_FAILED" = true ]; then
    warn "Automatic installation of the runtime libraries did not complete; checking whether they are already available."
fi

# Check the bundle before replacing an existing installation, so a failed
# dependency check leaves the old install and its menu entry intact.
echo -e "\033[1;36m==> [DigiDAW Install] Checking libraries...\033[0m"
if have ldd; then
    # Check the executable and the app's own libraries. Checking every bundled
    # plugin library reports false positives for libraries the loader resolves
    # at runtime or that never load on Linux. LD_LIBRARY_PATH lets ldd resolve
    # the libraries shipped next to the executable.
    MISSING_LIBRARIES="$(
        CHECK_FILES=("$APP_DIR/karbeat")
        for library in libapp.so libkarbeat_flutter_ffi.so libflutter_linux_gtk.so; do
            if [ -e "$APP_DIR/lib/$library" ]; then
                CHECK_FILES+=("$APP_DIR/lib/$library")
            fi
        done
        LD_LIBRARY_PATH="$APP_DIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
            ldd "${CHECK_FILES[@]}" 2>/dev/null |
            awk '/=> not found/ { print $1 }' |
            sort -u || true
    )"
    if [ -n "$MISSING_LIBRARIES" ]; then
        error "Some libraries are missing:"
        printf '%s\n' "$MISSING_LIBRARIES" | sed 's/^/    /'
        echo "Install GTK 3, ALSA, FFTW 3 (double precision), libsamplerate, and lilv, then run this script again."
        exit 1
    fi
else
    warn "ldd is not available; skipping the library check."
    if [ "$INSTALL_FAILED" = true ]; then
        error "The runtime libraries could not be installed and cannot be verified without ldd."
        exit 1
    fi
fi

echo -e "\033[1;36m==> [DigiDAW Install] Copying app to $INSTALL_DIR...\033[0m"
STAGING="$DATA_HOME/.digidaw-install.new"
OLD_INSTALL="$DATA_HOME/.digidaw-install.old"
restore_install() {
    rm -rf "$STAGING"
    if [ -d "$OLD_INSTALL" ] && [ ! -e "$INSTALL_DIR" ]; then
        mv "$OLD_INSTALL" "$INSTALL_DIR"
    fi
}
trap restore_install EXIT

mkdir -p "$DATA_HOME" "$BIN_DIR"
# Recover an install left behind by an interrupted update.
if [ -d "$OLD_INSTALL" ] && [ ! -e "$INSTALL_DIR" ]; then
    mv "$OLD_INSTALL" "$INSTALL_DIR"
fi
rm -rf "$STAGING" "$OLD_INSTALL"
mkdir -p "$STAGING" "$DATA_HOME/applications" "$ICON_DIR"
cp -a "$APP_DIR/." "$STAGING/"
rm -f "$STAGING/install.sh" "$STAGING/install_linux.sh"
if [ -e "$INSTALL_DIR" ]; then
    mv "$INSTALL_DIR" "$OLD_INSTALL"
fi
if ! mv "$STAGING" "$INSTALL_DIR"; then
    error "Could not move the new installation into $INSTALL_DIR."
    exit 1
fi
rm -rf "$OLD_INSTALL"
trap - EXIT

if [ ! -f "$ICON_SOURCE" ]; then
    warn "The release has no data/app_icon.png; the menu entry will use the default icon."
elif ! cp "$ICON_SOURCE" "$ICON_DIR/$APP_ID.png"; then
    warn "Could not install the application icon; the menu entry will use the default icon."
fi

# Quote the executable so an install path containing spaces still launches.
# A desktop entry string escapes a backslash with another one, and the quoted
# argument escapes the reserved characters, hence the doubled backslashes.
# shellcheck disable=SC2016 # sed escapes, not shell expansion
EXEC_PATH_ESCAPED="$(
    printf '%s' "$INSTALL_DIR/karbeat" |
        sed 's/\\/\\\\/g; s/"/\\\\"/g; s/\$/\\\\$/g; s/`/\\\\`/g'
)"

# Named after the application ID, which the main window and plugin windows report, so
# desktops match them to this entry and its icon.
rm -f "$DATA_HOME/applications/digidaw.desktop"
cat > "$DATA_HOME/applications/$APP_ID.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=DigiDAW
Comment=Digital audio workstation
Exec="$EXEC_PATH_ESCAPED"
Icon=$APP_ID
StartupNotify=true
StartupWMClass=$APP_ID
Categories=AudioVideo;Audio;
Terminal=false
EOF

if have update-desktop-database; then
    update-desktop-database "$DATA_HOME/applications" >/dev/null 2>&1 || true
fi

LAUNCHER_CREATED=true
if ln -sfn "$INSTALL_DIR/karbeat" "$BIN_DIR/digidaw"; then
    case ":$PATH:" in
        *":$BIN_DIR:"*) ;;
        *) echo -e "\033[1;33m==> NOTE: $BIN_DIR is not on your PATH; add it to run 'digidaw' from a terminal.\033[0m" ;;
    esac
else
    LAUNCHER_CREATED=false
    warn "Could not create the 'digidaw' launcher in $BIN_DIR."
fi

if ! have pipewire && ! have jackd; then
    warn "Neither PipeWire nor JACK was found. Install one for low-latency audio."
fi

if [ "$LAUNCHER_CREATED" = true ]; then
    echo -e "\033[1;32m==> SUCCESS: DigiDAW is installed. Launch it from your app menu or run 'digidaw'.\033[0m"
else
    echo -e "\033[1;32m==> SUCCESS: DigiDAW is installed. Launch it from your app menu.\033[0m"
fi
printf 'To uninstall, run: %q\n' "$INSTALL_DIR/uninstall.sh"
