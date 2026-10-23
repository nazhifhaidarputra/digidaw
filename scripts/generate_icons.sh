#!/usr/bin/env bash
# Regenerates every application icon from the SVG sources in assets/icon/.
#
# - assets/icon/app_icon.png and app_icon_foreground.png: 1024 px renders of the SVGs.
# - Android, iOS, macOS and Windows launcher icons, through flutter_launcher_icons
#   (configured in pubspec.yaml).
# - linux/runner/resources/app_icon.png: the Linux window and desktop-entry icon.
# - rust/karbeat-host-api/assets/window_icon_{32,64}.bgra: raw icons for native plugin
#   windows, as little-endian BGRA rows (one ARGB u32 per pixel).
#
# Needs ImageMagick 7 (`magick`) and Flutter.
set -euo pipefail

cd "$(dirname "$0")/.."

ICON_DIR="assets/icon"
# 8-bit RGBA: flutter_launcher_icons misreads 16-bit PNGs.
magick -background none "$ICON_DIR/app_icon.svg" -resize 1024x1024 "PNG32:$ICON_DIR/app_icon.png"
magick -background none "$ICON_DIR/app_icon_foreground.svg" -resize 1024x1024 \
    "PNG32:$ICON_DIR/app_icon_foreground.png"

dart run flutter_launcher_icons

magick "$ICON_DIR/app_icon.png" -resize 256x256 "PNG32:linux/runner/resources/app_icon.png"

HOST_ASSETS="rust/karbeat-host-api/assets"
mkdir -p "$HOST_ASSETS"
for size in 32 64; do
    magick "$ICON_DIR/app_icon.png" -resize "${size}x${size}" -depth 8 \
        "BGRA:$HOST_ASSETS/window_icon_$size.bgra"
done

echo "Icons regenerated."
