# Installation

DigiDAW is currently released for **Linux x64 only**, as it is the only platform that has been tested so far. Windows and Android builds are possible from source but are not released yet.

- [Installing a release](#installing-a-release)
- [Uninstalling](#uninstalling)
- [Building from source](#building-from-source)

---

## Installing a release

### Requirements

- A 64-bit (x86_64) Linux distribution with glibc 2.39 or newer, such as Ubuntu 24.04 or Debian 13. Releases are built on Ubuntu 24.04, so older distributions may not be able to run them.
- `sudo` access, to install the package or the libraries DigiDAW needs. The AppImage needs no `sudo`.
- PipeWire (with its JACK compatibility layer) or JACK, recommended for low-latency audio. ALSA works without them.

### Choosing a package

Each release on the [GitHub releases page](https://github.com/nazhifhaidarputra/digidaw/releases) has four files. Pick one:

| File | For | Installs to |
| --- | --- | --- |
| `digidaw_<version>-1_amd64.deb` | Debian, Ubuntu, and their derivatives | `/opt/digidaw`, for all users |
| `digidaw-<version>-1.x86_64.rpm` | Fedora, openSUSE, and other RPM distributions | `/opt/digidaw`, for all users |
| `DigiDAW-<version>-x86_64.AppImage` | Any distribution | Nowhere: it runs from the file |
| `digidaw-<version>-linux-x64.tar.gz` | Any distribution, including Arch | `~/.local/share/digidaw`, for you only |

Each file has a `.sha256` file next to it. To check a download, keep both in the same folder and run, for example:

```sh
sha256sum -c digidaw_<version>-1_amd64.deb.sha256
```

Rubber Band, which DigiDAW uses for offline pitch shifting and time stretching, is built into the app in every package, so you do not need to install it. Real-time stretching uses Signalsmith Stretch, which is compiled into the app from source.

### Debian and Ubuntu (.deb)

```sh
sudo apt install ./digidaw_<version>-1_amd64.deb
```

apt also installs the libraries DigiDAW needs: GTK 3, ALSA, FFTW, libsamplerate, and lilv (the LV2 plugin library). Launch DigiDAW from your app menu or run `digidaw`.

### Fedora and openSUSE (.rpm)

```sh
sudo dnf install ./digidaw-<version>-1.x86_64.rpm       # Fedora
sudo zypper install ./digidaw-<version>-1.x86_64.rpm    # openSUSE
```

The package manager also installs the libraries DigiDAW needs. On RHEL and its rebuilds, enable EPEL first so lilv is available. On immutable Fedora systems, use `rpm-ostree install` instead and reboot.

### AppImage

```sh
chmod +x DigiDAW-<version>-x86_64.AppImage
./DigiDAW-<version>-x86_64.AppImage
```

The AppImage carries FFTW, libsamplerate, and lilv itself, and uses GTK 3 and ALSA from your system, which every desktop has. It does not add a menu entry; tools such as Gear Lever or AppImageLauncher can do that.

### Any distribution, per user (.tar.gz)

1. Extract the archive into its own folder. The archive has no top-level folder, so create one:

   ```sh
   mkdir digidaw
   tar -xzf digidaw-<version>-linux-x64.tar.gz -C digidaw
   ```

2. Run the installer from that folder:

   ```sh
   cd digidaw
   ./install.sh
   ```

The installer:

- Installs GTK 3, ALSA, FFTW, libsamplerate, and lilv with your package manager (apt, dnf, pacman, or zypper). On RHEL and its rebuilds, enable EPEL first so `lilv-libs` is available; on immutable Fedora systems, layer the packages with `rpm-ostree`. On other distributions, install them yourself before running DigiDAW.
- Copies DigiDAW to `~/.local/share/digidaw`.
- Adds a `digidaw` command in `~/.local/bin` and a DigiDAW entry to your app menu.
- Checks that every library DigiDAW needs can be found, and lists any that are missing.

Once installed, launch DigiDAW from your app menu or run `digidaw`. If the command is not found, add `~/.local/bin` to your `PATH`.

Install DigiDAW one way only. A per-user install from the archive usually takes precedence over a .deb or .rpm, both in the app menu and on your `PATH`.

### Updating

Install the new release the same way as the old one: the .deb or .rpm with your package manager, a new AppImage in place of the old one, or the new archive's `install.sh`. Your settings are kept.

---

## Uninstalling

| Installed from | Remove with |
| --- | --- |
| .deb | `sudo apt remove digidaw` |
| .rpm | `sudo dnf remove digidaw` or `sudo zypper remove digidaw` |
| AppImage | Delete the file. |
| .tar.gz | `~/.local/share/digidaw/uninstall.sh`, or `./uninstall.sh` from an extracted release folder |

This removes the app, the `digidaw` command, and the app menu entry. It keeps:

- **Your settings and crash recovery data,** in `~/.local/share/app.digidaw.Digidaw`. For the archive install, add `--purge` to the uninstaller to delete them too; crash recovery data can contain unsaved work, so you are asked to confirm first. For the other packages, delete that folder yourself.
- **Your projects.** Uninstalling never touches your project files.
- **The system libraries** (GTK 3, ALSA, FFTW, libsamplerate, lilv), because other software may use them.

---

## Building from source

### Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install/linux) (stable channel, 3.44 or newer)
- [Rust](https://www.rust-lang.org/tools/install) (stable toolchain)
- PipeWire or JACK
- On Linux, `sudo` access to install build dependencies

### Building a Linux release

From the repository root, run:

```sh
./scripts/builder/build_linux.sh
```

The script:

1. Installs the build dependencies with your package manager: clang, CMake, Ninja, Meson, pkg-config, and the GTK 3, ALSA, JACK, Rubber Band, FFTW, libsamplerate, and lilv development packages.
2. Builds Rubber Band 4.0 from source as a static library in `build/rubberband`, so the app does not depend on the distribution's Rubber Band. This only happens the first time, or after `build/` is cleaned.
3. Installs `flutter_rust_bridge_codegen` if it is missing, and regenerates the Flutter Rust Bridge bindings.
4. Downloads the tempo detection models into `assets/models`.
5. Builds the Flutter Linux release.
6. Packages it into `dist/`, in the same four formats as a release, each with a `.sha256` file: the `.tar.gz` archive (with `install.sh` and `uninstall.sh`), the `.deb`, the `.rpm`, and the AppImage. The first time, it downloads the packaging tools, nfpm and appimagetool, into `build/packaging-tools`.

You can install the packages in `dist/` straight away, as described in [Installing a release](#installing-a-release), without waiting for a GitHub release. A package built on your machine needs your distribution's glibc version or newer, so it may not run on older distributions.

To package the last build again without rebuilding, for example after changing the packaging, run:

```sh
./scripts/builder/package_linux.sh
```

Set `PACKAGE_FORMATS` to build only some formats, for example `PACKAGE_FORMATS="rpm appimage" ./scripts/builder/package_linux.sh`.

### Running for development

For day-to-day development, the app builds against the system Rubber Band instead. Your distribution must package **Rubber Band 4.0 or newer** (for example, Ubuntu 26.04, or current Fedora and Arch), because DigiDAW uses its live pitch shifter API. Install the same packages as above, then run:

```sh
./scripts/fetch_beat_models.sh
flutter pub get
flutter run -d linux
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for project structure, conventions, and how to validate changes.
