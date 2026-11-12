#!/usr/bin/env bash
# Packages the Flutter Linux release bundle into dist/, each file with a .sha256 next to it:
#
#   digidaw-<version>-linux-x64.tar.gz   the bundle with install.sh and uninstall.sh
#   digidaw_<version>-1_amd64.deb        Debian, Ubuntu and their derivatives
#   digidaw-<version>-1.x86_64.rpm       Fedora, openSUSE and other RPM distributions
#   DigiDAW-<version>-x86_64.AppImage    runs without installing
#
# build_linux.sh runs this after building. Run it alone to repackage the last build:
#   scripts/builder/package_linux.sh [bundle-dir]
# PACKAGE_FORMATS picks the formats, e.g. PACKAGE_FORMATS="deb rpm"; all four by default.
#
# nfpm (for .deb and .rpm) and appimagetool are downloaded at pinned versions, checked
# against their checksums, into build/packaging-tools.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
RESOURCES="$ROOT/scripts/builder/linux"
BUNDLE_DIR="$(cd "${1:-$ROOT/build/linux/x64/release/bundle}" 2>/dev/null && pwd || true)"
DIST_DIR="$ROOT/dist"
TOOLS_DIR="$ROOT/build/packaging-tools"
STAGE_DIR="$ROOT/build/packaging"
FORMATS=" ${PACKAGE_FORMATS:-tar deb rpm appimage} "
APP_ID="app.digidaw.Digidaw"

NFPM_VERSION="2.48.0"
NFPM_SHA256="6d7f9a28b2f397934403950fcbba83f598b08d02edbe79a0815b3b4897341750"
APPIMAGETOOL_VERSION="1.9.1"
APPIMAGETOOL_SHA256="ed4ce84f0d9caff66f50bcca6ff6f35aae54ce8135408b3fa33abfc3cb384eb0"
# The AppImage runtime is the stub that mounts the image when it runs. appimagetool would
# download the latest one; pinning it keeps builds reproducible.
APPIMAGE_RUNTIME_VERSION="20251108"
APPIMAGE_RUNTIME_SHA256="2fca8b443c92510f1483a883f60061ad09b46b978b2631c807cd873a47ec260d"

step() { echo -e "\033[1;36m==> [Linux Package] $*\033[0m"; }
fail() {
    echo -e "\033[1;31m==> ERROR: $*\033[0m"
    exit 1
}
wants() { [[ "$FORMATS" == *" $1 "* ]]; }

if [ -z "$BUNDLE_DIR" ] || [ ! -x "$BUNDLE_DIR/karbeat" ]; then
    fail "No release bundle at ${1:-build/linux/x64/release/bundle}; run build_linux.sh first."
fi
case "$(uname -m)" in
    x86_64 | amd64) ;;
    *) fail "The packages are for x86_64; this machine is $(uname -m)." ;;
esac
for format in $FORMATS; do
    case "$format" in
        tar | deb | rpm | appimage) ;;
        *) fail "Unknown package format '$format'; use tar, deb, rpm or appimage." ;;
    esac
done

VERSION="$(sed -n 's/^version: *\([^ +]*\).*/\1/p' "$ROOT/pubspec.yaml")"
[ -n "$VERSION" ] || fail "Could not read the version from pubspec.yaml."

# Downloads $2 to $1 unless a file with checksum $3 is already there.
fetch() {
    local target="$1" url="$2" sha256="$3"
    if [ -f "$target" ] && echo "$sha256  $target" | sha256sum -c --status -; then
        return
    fi
    mkdir -p "$(dirname "$target")"
    curl -fL --retry 3 -o "$target.part" "$url"
    echo "$sha256  $target.part" | sha256sum -c --status - || fail "Checksum mismatch for $url"
    mv "$target.part" "$target"
}

checksum() {
    (cd "$DIST_DIR" && sha256sum "$1" > "$1.sha256")
}

# A copy of the bundle without the per-user install scripts, which only the archive carries.
step "Staging the bundle..."
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR" "$DIST_DIR"
cp -a "$BUNDLE_DIR" "$STAGE_DIR/app"
rm -f "$STAGE_DIR/app/install.sh" "$STAGE_DIR/app/uninstall.sh"

# Packages from an earlier build would be published next to the new ones.
rm -f "$DIST_DIR"/digidaw-*-linux-x64.tar.gz* "$DIST_DIR"/digidaw_*_amd64.deb* \
    "$DIST_DIR"/digidaw-*.x86_64.rpm* "$DIST_DIR"/DigiDAW-*-x86_64.AppImage*

if wants tar; then
    step "Archiving the bundle..."
    cp -a "$STAGE_DIR/app" "$STAGE_DIR/tar"
    cp "$ROOT/scripts/installer/install_linux.sh" "$STAGE_DIR/tar/install.sh"
    cp "$ROOT/scripts/installer/uninstall_linux.sh" "$STAGE_DIR/tar/uninstall.sh"
    ARCHIVE="digidaw-$VERSION-linux-x64.tar.gz"
    tar -czf "$DIST_DIR/$ARCHIVE" -C "$STAGE_DIR/tar" .
    checksum "$ARCHIVE"
fi

if wants deb || wants rpm; then
    # The packages require the newest glibc symbol version the bundle uses: the glibc of
    # the build machine, unless nothing needed its newest symbols.
    GLIBC_VERSION="$(
        { find "$STAGE_DIR/app" -type f \( -name '*.so*' -o -perm -u+x \) \
            -exec objdump -T {} + 2>/dev/null || true; } |
            { grep -o 'GLIBC_[0-9][0-9.]*' || true; } |
            sed 's/^GLIBC_//' | sort -Vu | tail -n 1
    )"
    [ -n "$GLIBC_VERSION" ] || fail "Could not find the glibc version the bundle needs (is objdump installed?)."

    fetch "$TOOLS_DIR/nfpm-$NFPM_VERSION.tar.gz" \
        "https://github.com/goreleaser/nfpm/releases/download/v$NFPM_VERSION/nfpm_${NFPM_VERSION}_Linux_x86_64.tar.gz" \
        "$NFPM_SHA256"
    NFPM="$TOOLS_DIR/nfpm-$NFPM_VERSION/nfpm"
    if [ ! -x "$NFPM" ]; then
        mkdir -p "$(dirname "$NFPM")"
        tar -xzf "$TOOLS_DIR/nfpm-$NFPM_VERSION.tar.gz" -C "$(dirname "$NFPM")" nfpm
    fi

    export DIGIDAW_VERSION="$VERSION" DIGIDAW_STAGE="$STAGE_DIR" \
        DIGIDAW_RESOURCES="$RESOURCES" DIGIDAW_GLIBC="$GLIBC_VERSION"
    for packager in deb rpm; do
        wants "$packager" || continue
        step "Building the .$packager package (needs glibc $GLIBC_VERSION or newer)..."
        "$NFPM" package --config "$RESOURCES/nfpm.yaml" --packager "$packager" --target "$DIST_DIR/"
    done
    for package in "$DIST_DIR"/digidaw_*_amd64.deb "$DIST_DIR"/digidaw-*.x86_64.rpm; do
        if [ -f "$package" ]; then
            checksum "$(basename "$package")"
        fi
    done
fi

if wants appimage; then
    step "Building the AppImage..."
    APPIMAGETOOL="$TOOLS_DIR/appimagetool-$APPIMAGETOOL_VERSION-x86_64.AppImage"
    RUNTIME="$TOOLS_DIR/appimage-runtime-$APPIMAGE_RUNTIME_VERSION-x86_64"
    fetch "$APPIMAGETOOL" \
        "https://github.com/AppImage/appimagetool/releases/download/$APPIMAGETOOL_VERSION/appimagetool-x86_64.AppImage" \
        "$APPIMAGETOOL_SHA256"
    fetch "$RUNTIME" \
        "https://github.com/AppImage/type2-runtime/releases/download/$APPIMAGE_RUNTIME_VERSION/runtime-x86_64" \
        "$APPIMAGE_RUNTIME_SHA256"
    chmod +x "$APPIMAGETOOL"

    APPDIR="$STAGE_DIR/AppDir"
    mkdir -p "$APPDIR/usr/lib"
    cp -a "$STAGE_DIR/app" "$APPDIR/usr/lib/digidaw"
    install -m 755 "$RESOURCES/AppRun" "$APPDIR/AppRun"
    cp "$RESOURCES/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
    cp "$STAGE_DIR/app/data/app_icon.png" "$APPDIR/$APP_ID.png"
    ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

    # Carry the libraries few desktops have installed: FFTW, libsamplerate, and lilv with
    # the libraries it needs. GTK 3 and ALSA come from the system, as on every desktop.
    BUNDLED_LIBRARIES="$(
        LD_LIBRARY_PATH="$STAGE_DIR/app/lib" ldd "$STAGE_DIR/app/lib/libkarbeat_flutter_ffi.so" 2>/dev/null |
            awk '$2 == "=>" && $3 ~ /^\// { print $1, $3 }'
    )"
    while read -r soname path; do
        case "$soname" in
            libfftw3.so.* | libsamplerate.so.* | liblilv-0.so.* | libserd-0.so.* | \
                libsord-0.so.* | libsratom-0.so.* | libzix-0.so.*)
                cp -L "$path" "$APPDIR/usr/lib/$soname"
                ;;
        esac
    done <<< "$BUNDLED_LIBRARIES"
    [ -e "$APPDIR/usr/lib/liblilv-0.so.0" ] || fail "lilv was not found to put in the AppImage."

    APPIMAGE="DigiDAW-$VERSION-x86_64.AppImage"
    # Extract-and-run lets appimagetool run where FUSE is unavailable, as on CI runners.
    ARCH=x86_64 APPIMAGE_EXTRACT_AND_RUN=1 "$APPIMAGETOOL" \
        --runtime-file "$RUNTIME" "$APPDIR" "$DIST_DIR/$APPIMAGE"
    checksum "$APPIMAGE"
fi

echo -e "\033[1;32m==> SUCCESS: Packaged DigiDAW $VERSION:\033[0m"
for package in "$DIST_DIR"/*; do
    case "$package" in
        *.sha256) ;;
        *.tar.gz | *.deb | *.rpm | *.AppImage) echo "    dist/$(basename "$package")" ;;
    esac
done
