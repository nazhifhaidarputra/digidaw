#!/usr/bin/env bash
# Removes a DigiDAW installation made by install.sh.
#
# Removes the app, the `digidaw` launcher, and the desktop menu entry and icon. Settings and crash
# recovery data are kept unless --purge is given. The system libraries install.sh installed
# (GTK 3, ALSA, FFTW, libsamplerate) are left in place because other software may use them.
# build_linux.sh ships this script in the archive as uninstall.sh, and install.sh keeps a
# copy in the install folder.
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
INSTALL_DIR="$DATA_HOME/digidaw"
LAUNCHER="$HOME/.local/bin/digidaw"
APP_ID="app.digidaw.Digidaw"
# The entry is named after the application ID; older installs used digidaw.desktop.
DESKTOP_ENTRIES=("$DATA_HOME/applications/$APP_ID.desktop" "$DATA_HOME/applications/digidaw.desktop")
ICON="$DATA_HOME/icons/hicolor/256x256/apps/$APP_ID.png"
# path_provider names the data folder after the application ID; older installs used the
# template ID or the binary name.
APP_DATA_DIRS=("$DATA_HOME/$APP_ID" "$DATA_HOME/com.example.karbeat" "$DATA_HOME/karbeat")

PURGE=false
case "${1:-}" in
    "") ;;
    --purge) PURGE=true ;;
    *)
        echo "Usage: $0 [--purge]"
        echo "  --purge  Also delete DigiDAW settings and crash recovery data."
        exit 1
        ;;
esac

echo -e "\033[1;36m==> [DigiDAW Uninstall] Removing app...\033[0m"
if [ -L "$LAUNCHER" ] && [ "$(readlink "$LAUNCHER")" = "$INSTALL_DIR/karbeat" ]; then
    rm -f "$LAUNCHER"
fi
rm -f "${DESKTOP_ENTRIES[@]}" "$ICON"
rm -rf "$INSTALL_DIR"

if [ "$PURGE" = true ]; then
    echo -e "\033[1;33m==> This deletes DigiDAW settings and crash recovery data (unsaved auto-saves).\033[0m"
    if [ -t 0 ]; then
        read -r -p "Continue? [y/N] " answer
        case "$answer" in
            [yY]*) ;;
            *) echo "Kept settings and crash recovery data."; PURGE=false ;;
        esac
    fi
fi
if [ "$PURGE" = true ]; then
    echo -e "\033[1;36m==> [DigiDAW Uninstall] Removing settings and crash recovery data...\033[0m"
    rm -rf "${APP_DATA_DIRS[@]}"
fi

echo -e "\033[1;32m==> SUCCESS: DigiDAW has been uninstalled.\033[0m"
if [ "$PURGE" = false ]; then
    echo "Settings and crash recovery data were kept; run with --purge to delete them."
fi
echo "Your projects and the system libraries (GTK 3, ALSA, FFTW, libsamplerate) were not touched."
