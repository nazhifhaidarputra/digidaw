<!-- <div align="center">
  <h1>🎵 DigiDAW</h1>
  <img src="./assets/images/Digidaw_logo.png"/>
  <p><strong>A minimal, cross-platform Digital Audio Workstation (DAW) written in Flutter and Rust.</strong></p>
</div> -->

# Digidaw

DigiDAW (formerly "Karbeat") is a clean, simple, and minimal Digital Audio Workstation (DAW) designed to be cross-platform. We prioritize delivering an effective mobile-first application

By leveraging the performance of [Rust](https://www.rust-lang.org/) for audio processing and the versatile UI capabilities of [Flutter](https://flutter.dev/), DigiDAW aims to provide a reliable environment for your musical creativity.

## Features

- **Cross-Platform**: Built for Windows and Linux, with Android support planned in the near future.
- **High-Performance Audio**: Core audio engine built in Rust using [CPAL](https://github.com/RustAudio/cpal).
- **Minimalist Interface**: A clean UI developed with Flutter for a distraction-free workflow.

More features are currently in active development.

## Roadmap

These are features which have been or have not been implemented. All unimplemented features will be implemented in the future

- [x] Ser/De project file
- [x] Export Audio to MP3 and Wav
- [x] Audio Waveform sequencing
- [x] Working real-time transport controller
- [x] Automation for mixer channel and mixer channel plugin
- [x] Clip level manipulation (Copy, Cut, Paste, Slice, resize, move, and its batch operation) for both audio waveform clip and MIDI clip
- [x] Piano roll MIDI note drawing
- [x] Simple Synthesizers
- [x] Parametric EQ  
- [x] Mixer Routing (Partially)
- [x] Bus Automation lanes rack
- [ ] Action history (Undo/Redo)
- [ ] Finishing and optimizing Bus Mixer Routing
- [ ] Time-stretched audio waveform processing
- [ ] Automation for generator and global parameters
- [ ] Wavetable Synthesizer
- [ ] Sample-based Synthesizer (for Real instrument)
- [ ] Common Audio FX (Reverb, Distortion, Compressor, Multiband Compressor, Sidechain Compressor, Dynamic Compressor, Flanger, Phaser, Chorus, etc.)
- [ ] Browser panel for easy drag-and-drop audio samples
- [ ] Input channel for input recording
- [ ] Auxiliary input handler (WIP)
- [ ] Refactor UI for better UX and responsiveness in mobile platform
- [ ] Third-party supports for native audio plugin (In form of Asset Workshop)
- [ ] Settings/configuration for user
- [ ] Logging for end-user
- [ ] VST3/AU Host support
- [ ] CLAP Host support
- [ ] LV2 Host support
- [ ] Plugin Scanner
- [ ] MacOS version
- [ ] iOS version
- [ ] Export audio to FLAC and OGG
- [ ] Tempo detector and Fit-to-tempo functionality
- [ ] Version manager
- [ ] Comprehensive Documentation for both User and Developer

## Tech Stack

- **Frontend**: [Flutter](https://flutter.dev/) & Dart
- **Audio Engine**: [Rust](https://www.rust-lang.org/)
- **Audio Host**: [CPAL (Cross-Platform Audio Library)](https://github.com/RustAudio/cpal)
- **Bridge**: [Flutter Rust Bridge](https://fzyzcjy.github.io/flutter_rust_bridge/)

## 👥 Contributors

A huge thanks to the developers who made this project possible:

| <a href="https://codeberg.org/haidarptrw"><img src="https://codeberg.org/avatars/52b87e29a45aa11b374f02b83c5d6d42" width="80px;" alt=""/></a><br /><sub><b>[haidarptrw](https://codeberg.org/haidarptrw)</b></sub> |
| :--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|                                                                    **Creator, Lead Developer & Audio Engineer**                                                                    |

_(Want to contribute? Check out our developer notes below!)_

## 📚 References & Documentation

Currently, technical documentation and detailed info are still being drafted. Please be patient as we focus on building the core features of the app!

## 👨‍💻 Note for Developers

Thank you for your interest in Digidaw! Here are a few things to keep in mind:

- **Current Focus**: The application is currently prioritizing **Windows** and **Linux** as the primary development environment for faster development. We will focus to complete features to an usable state for users. Eventually we will fully focus on mobile devices support as it is our main priority in the first place
- **Future Platforms**: Once the core application is near completion, we'll implement and optimize features for **Android**.
- **Plugin Host Support**: We will add plugin host and support for VST3, CLAP, and LV2 for Windows, Linux, and MacOS version. As for android, we are still exploring the best fit and possibility of creating our own plugin format.
- **Plugin Development**: Currently our plugin registry is very few. You can help to create a plugin by using the Karbeat Plugin API by implementing the `AudioPlugin` trait.

---

## Licensing

This project uses a split-licensing model to support both open-source collaboration and proprietary plugin development:
- **Framework & API Crates (`karbeat-plugin-api`, `karbeat-plugin-types`, `karbeat-macros`, `karbeat-utils`, `karbeat-host`)**: Licensed under **Apache-2.0 OR MIT**. You can freely use these to build closed-source or proprietary audio plugins.
- **DSP Library (`karbeat-dsp`)**: Licensed under **GPLv3**. If you decided to use this in your audio plugin implementation, you should also open-source your plugin
- **Core Application (`karbeat-core`, `karbeat-flutter-ffi`, Flutter UI) & First-Party Plugins**: Licensed under **GPLv3 with a Linking Exception**. This allows you to dynamically link and run closed-source, proprietary plugins inside the Digidaw DAW engine.

## Regarding the Future of the Project

We decided to rename the project from Karbeat to DigiDAW. Originally, DigiDAW was going to be the name of the desktop version of the DAW, which would support VST, CLAP, and AU plugins. However, we decided to focus only on the mobile application for now. We are also planning to add an audio plugin interface that supports third-party plugins built as dynamic libraries on both Android and iOS.

Meanwhile, our desktop DAW, will utilize a distinct frontend
implementation and a modified backend to accommodate new technologies.
We intend to build the desktop version entirely in Rust, though we are still researching the best framework for the task.
This shift is necessary because the desktop version will include features incompatible with mobile platforms, such as
broad support for popular audio plugin formats like VST3, LV2, CLAP, and AU. Furthermore, Rust offers superior performance
for desktop GUI applications compared to Flutter, whose garbage collector can impact real-time efficiency.

## Supporting this Project

To support this project, you can donate to my Ko-Fi [here](https://ko-fi.com/haidarwibowo)
