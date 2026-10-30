# DigiDAW

DigiDAW (formerly "Karbeat") is a clean, simple, and minimal Digital Audio Workstation (DAW). It pairs a Flutter frontend with a Rust audio engine, so the interface stays flexible while the real-time audio path stays predictable.

The project is desktop-first today: **Linux x64 is the only released platform**. Windows and Android can be built from source, but are not released yet. macOS and iOS are not supported yet. Mobile is the long-term target, and the UI will be reworked for touch before mobile releases.

## Features

- **Audio engine**: A real-time Rust engine built on [CPAL](https://github.com/RustAudio/cpal), with pre-allocated buffers, lock-free telemetry, and a dedicated DSP path.
- **Arrangement and editing**: Audio and MIDI clips, patterns, ghost clips, and copy, cut, paste, slice, resize, move, and batch editing. Undo and redo are backed by the engine's action history.
- **Piano roll**: MIDI note drawing and editing, note copy/paste, and an on-screen MIDI keyboard.
- **Mixer**: Tracks, buses, master bus, routing, metering, sidechain routing, and automation lanes for mixer channels and plugin parameters.
- **Built-in instruments and effects**: The Karbeatzer V2 and My Retro synthesizers, plus Parametric EQ, Delay, Pitch Shifter, and Sidechain Compressor effects.
- **Plugin hosting**: VST3 and CLAP on Linux and Windows, and LV2 on Linux.
- **Time stretching and pitch shifting**: Signalsmith Stretch for real-time playback and Rubber Band for offline renders.
- **Tempo tools**: Tempo, beat, and downbeat detection with [Beat This!](https://github.com/CPJKU/beat_this), plus fit-to-tempo for audio sources.
- **Recording and input**: Audio input recording and monitoring, with auxiliary input handling.
- **Projects and export**: `.dgdaw` project files, and WAV, MP3, FLAC, and OGG export with metadata.
- **Audio and device setup**: Host and device selection through CPAL, including ASIO, WASAPI, JACK, ALSA, and CoreAudio where available.
- **Reliability**: Auto-save, crash recovery, local crash reports, diagnostic logging, and a startup recovery prompt.
- **Customization**: Light, dark, and Catppuccin themes, plus configurable keyboard shortcuts.
- **Sample browsing**: A browser panel for dragging and dropping audio samples into the arrangement.

## Installation

Released builds are published on the [GitHub releases page](https://github.com/nazhifhaidarputra/digidaw/releases). The current release targets **Linux x64 only**.

See [INSTALLATION.md](INSTALLATION.md) for installation, uninstallation, prerequisites, and building from source.

For development on Linux, the short version is:

```sh
./scripts/fetch_beat_models.sh
flutter pub get
flutter run -d linux
```

Building a release bundle is handled by `./scripts/builder/build_linux.sh`. Windows and Android build scripts live in `scripts/builder/` as well.

## Roadmap

### Implemented

- [x] Ser/De project file (`.dgdaw` format)
- [x] Export audio to WAV, MP3, FLAC, and OGG
- [x] Audio waveform sequencing, patterns, and ghost clips
- [x] Working real-time transport controller
- [x] Automation for mixer channels, buses, and plugin parameters
- [x] Clip-level manipulation (copy, cut, paste, slice, resize, move, and batch operations) for both audio and MIDI clips
- [x] Piano roll MIDI note drawing and editing
- [x] Built-in synthesizers (Karbeatzer V2 and My Retro)
- [x] Parametric EQ, delay, pitch shifter, and sidechain compressor
- [x] Mixer routing and bus automation lanes
- [x] Real-time pitch shifting and time stretching (Signalsmith Stretch), with offline renders via Rubber Band
- [x] Action history (undo/redo)
- [x] Audio host and device selector (ASIO, WASAPI, JACK, ALSA, and CoreAudio through CPAL)
- [x] Automation for generator parameters
- [x] Browser panel for drag-and-drop audio samples
- [x] Input channel for recording and monitoring
- [x] Auxiliary input handler
- [x] Settings and configuration for users
- [x] Logging for end users
- [x] VST3 host (Linux and Windows)
- [x] CLAP host (Linux and Windows)
- [x] LV2 host (Linux)
- [x] Tempo detection and fit-to-tempo
- [x] Auto-save
- [x] Crash reporting and crash recovery
- [x] Official logo and launcher icons
- [x] Theme customization and configurable keyboard shortcuts

### Planned

- [ ] Tempo (BPM) automation in the UI; the engine already supports the automation target
- [ ] Wavetable synthesizer (early work in progress)
- [ ] Sample-based synthesizer for real instruments
- [ ] Audio sampler
- [ ] More audio effects (reverb, distortion, compressor, multiband compressor, flanger, phaser, chorus)
- [ ] AU host support (macOS)
- [ ] macOS version
- [ ] iOS version
- [ ] UI refactor for better UX and responsiveness on mobile
- [ ] Comprehensive user and developer documentation

## Tech Stack

- **Frontend**: [Flutter](https://flutter.dev/) and Dart, with Riverpod and Freezed
- **Audio Engine**: [Rust](https://www.rust-lang.org/)
- **Audio Host**: [CPAL (Cross-Platform Audio Library)](https://github.com/RustAudio/cpal)
- **Bridge**: [Flutter Rust Bridge](https://fzyzcjy.github.io/flutter_rust_bridge/)
- **Time stretching and pitch shifting**: [Signalsmith Stretch](https://github.com/Signalsmith-Audio/signalsmith-stretch) for real-time use, [Rubber Band](https://breakfastquay.com/rubberband/) for offline renders
- **Tempo and beat analysis**: [Beat This!](https://github.com/CPJKU/beat_this) via the `beat-this` crate on the `rten` runtime
- **Plugin hosting**: VST3, CLAP, and LV2

## 👥 Contributors

A huge thanks to the developers who made this project possible:

| <a href="https://codeberg.org/haidarptrw"><img src="https://codeberg.org/avatars/52b87e29a45aa11b374f02b83c5d6d42" width="80px;" alt=""/></a><br /><sub><b>[haidarptrw](https://codeberg.org/haidarptrw)</b></sub> |
| :----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|                                                                                    **Creator, Lead Developer & Audio Engineer**                                                                                    |

_(Want to contribute? Check out our developer notes below!)_

## 📚 References & Documentation

- [INSTALLATION.md](INSTALLATION.md): installation, uninstallation, and building from source
- [CONTRIBUTING.md](CONTRIBUTING.md): project structure, conventions, audio-thread rules, and validation commands
- [Crash Error Code Guide](docs/CODE_ERROR_GUIDE.md): what each crash report code means
- [Audio Plugin Manifest Info](assets/manifests/audio-plugins/PLUGIN_MANIFEST_INFO.md): how first-party plugin manifests are written

Comprehensive user and developer documentation is still being drafted.

## 👨‍💻 Note for Developers

Thank you for your interest in DigiDAW! Here are a few things to keep in mind:

- **Current Focus**: **Linux** is the primary development and release platform. Windows and Android build from source, but need more testing before they are released.
- **Future Platforms**: macOS and iOS support will follow after the desktop core and mobile UI are ready. The UI needs a dedicated touch-first pass before mobile releases.
- **Plugin Host Support**: VST3 and CLAP are hosted on Windows and Linux, and LV2 on Linux. AU support is planned for macOS. Android plugin hosting is still being explored.
- **Plugin Development**: First-party plugins live in `rust/karbeat-plugins` and implement the `AudioPlugin` trait from the Karbeat Plugin API. Their manifests live in `assets/manifests/audio-plugins/`, and the generated Flutter bindings come from those manifests.
- **Internal naming**: The project is DigiDAW, but packages, crates, and imports still use the internal name `karbeat`.

Read [CONTRIBUTING.md](CONTRIBUTING.md) before changing the Rust engine, the Flutter state layer, or the FFI boundary.

---

## Licensing

This project uses a split-licensing model to support both open-source collaboration and proprietary plugin development:

- **Framework & API Crates** (`karbeat-plugin-api`, `karbeat-plugin-types`, `karbeat-macros`, `karbeat-utils`, `karbeat-host`, `karbeat-host-api`): Licensed under **Apache-2.0 OR MIT**. You can freely use these to build closed-source or proprietary audio plugins.
- **DSP and analysis crates** (`karbeat-dsp`, `karbeat-rb`, `karbeat-signalsmith`, `karbeat-analysis`): Licensed under **GPLv3**. If you use these in an audio plugin implementation, you should also open-source your plugin.
- **Plugin format executors** (`karbeat-vst3`, `karbeat-clap`, `karbeat-lv2`): Licensed under **GPLv3**.
- **Core Application** (`karbeat-core`, `karbeat-core-api`, `karbeat-audio`, `karbeat-flutter-ffi`, Flutter UI) and **First-Party Plugins** (`karbeat-plugins`): Licensed under **GPLv3 with a Linking Exception**. This allows you to dynamically link and run closed-source, proprietary plugins inside the DigiDAW audio engine. See [LICENSE-EXCEPTION.txt](LICENSE-EXCEPTION.txt).

See [LICENSE.txt](LICENSE.txt) for the full license text.

## Regarding the Future of the Project

The project was renamed from Karbeat to DigiDAW. The internal name `karbeat` remains in package names, crate names, and imports, so you will still see it throughout the codebase.

Today the desktop application is built with Flutter and Rust, with Linux x64 as the released platform. Windows and Android support is buildable from source, and macOS/iOS support plus a touch-first mobile interface remain on the roadmap. The desktop app keeps broad plugin-format support as a priority, which is why VST3, CLAP, and LV2 hosting landed before mobile releases.

## Supporting this Project

To support this project, you can donate to my Ko-Fi [here](https://ko-fi.com/haidarwibowo)
