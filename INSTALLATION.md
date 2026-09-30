# Installation

DigiDAW is currently released for **Linux x64 only**, as it is the only platform that has been tested so far. Windows and Android builds are possible from source but are not released yet.

- [Installing a release](#installing-a-release)
- [Uninstalling](#uninstalling)
- [Building from source](#building-from-source)

---

## Installing a release

### Requirements

- A 64-bit (x86_64) Linux distribution as recent as Ubuntu 26.04. Releases are built on Ubuntu 26.04, so older distributions may not be able to run them.
- `sudo` access, so the installer can install the libraries DigiDAW needs.
- PipeWire (with its JACK compatibility layer) or JACK, recommended for low-latency audio. ALSA works without them.

### Steps

1. Download `digidaw-<version>-linux-x64.tar.gz` from the [GitHub releases page](https://github.com/nazhifhaidarputra/digidaw/releases).
2. Optionally, check the download against the `.sha256` file published next to it:

   ```sh
   sha256sum -c digidaw-<version>-linux-x64.tar.gz.sha256
   ```

3. Extract the archive into its own folder. The archive has no top-level folder, so create one:

   ```sh
   mkdir digidaw
   tar -xzf digidaw-<version>-linux-x64.tar.gz -C digidaw
   ```

4. Run the installer from that folder:

   ```sh
   cd digidaw
   ./install.sh
   ```

The installer:

- Installs GTK 3, ALSA, FFTW, and libsamplerate with your package manager (apt, dnf, pacman, or zypper). On other distributions, install them yourself before running DigiDAW.
- Copies DigiDAW to `~/.local/share/digidaw`.
- Adds a `digidaw` command in `~/.local/bin` and a DigiDAW entry to your app menu.
- Checks that every library DigiDAW needs can be found, and lists any that are missing.

Rubber Band, which DigiDAW uses for pitch shifting and time stretching, is built into the app, so you do not need to install it.

Once installed, launch DigiDAW from your app menu or run `digidaw`. If the command is not found, add `~/.local/bin` to your `PATH`.

### Updating

Download the new release and run its `install.sh` the same way. It replaces the installed app and keeps your settings.

---

## Uninstalling

Run the uninstaller that the installer keeps in the install folder:

```sh
~/.local/share/digidaw/uninstall.sh
```

You can also run `./uninstall.sh` from an extracted release folder.

This removes the app, the `digidaw` command, and the app menu entry. It keeps:

- **Your settings and crash recovery data.** Add `--purge` to delete them too. Crash recovery data can contain unsaved work, so you are asked to confirm first.
- **Your projects.** The uninstaller never touches your project files.
- **The system libraries** (GTK 3, ALSA, FFTW, libsamplerate), because other software may use them.

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

1. Installs the build dependencies with your package manager: clang, CMake, Ninja, Meson, pkg-config, and the GTK 3, ALSA, JACK, Rubber Band, FFTW, and libsamplerate development packages.
2. Builds Rubber Band 4.0 from source as a static library in `build/rubberband`, so the app does not depend on the distribution's Rubber Band. This only happens the first time, or after `build/` is cleaned.
3. Installs `flutter_rust_bridge_codegen` if it is missing, and regenerates the Flutter Rust Bridge bindings.
4. Downloads the tempo detection models into `assets/models`.
5. Builds the Flutter Linux release and packages it, together with `install.sh` and `uninstall.sh`, into `dist/Digidaw-linux-x64.tar.gz`.

### Running for development

For day-to-day development, the app builds against the system Rubber Band instead. Your distribution must package **Rubber Band 4.0 or newer** (for example, Ubuntu 26.04, or current Fedora and Arch), because DigiDAW uses its live pitch shifter API. Install the same packages as above, then run:

```sh
./scripts/fetch_beat_models.sh
flutter pub get
flutter run -d linux
```

See [CONTRIBUTING.md](CONTRIBUTING.md) for project structure, conventions, and how to validate changes.
