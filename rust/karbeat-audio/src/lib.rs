//! # Overview
//!
//! DSP audio engine, device stream, offline rendering, telemetry, and plugin hosting.
//! The persisted project model and application context live in `karbeat-core`; this crate
//! owns the real-time engine and the control plane that feeds it.

#![allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the real-time engine uses bounded sample-domain conversions and non-blocking best-effort channels"
)]

#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the real-time engine uses bounded sample-domain conversions and non-blocking best-effort channels"
)]
/// Device stream backend, runtime settings, and stream supervision.
pub mod backend;
/// Adapters that install first-party plugins into the audio engine.
pub mod builtin_plugin;
/// Bounded UI-to-audio commands and audio-to-UI feedback payloads.
pub mod commands;
#[allow(
    clippy::let_underscore_must_use,
    reason = "context broadcasts use non-blocking channels whose disconnected receivers are intentionally ignored"
)]
/// Application-owned project state and audio communication endpoints.
pub mod context;
/// Real-time render engine, graph scheduling, voices, routing, and telemetry.
pub mod engine;
/// Transport feedback and plugin targeting shared with the UI.
pub mod event;
/// Offline render preparation, snapshotting, and export orchestration.
pub mod exporter;
/// External plugin installation, replacement, removal, and native endpoint transfer.
pub mod hosted_plugin;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "startup signal generation converts fixed bounded constants and sends an optional one-shot command"
)]
/// Audio-engine startup and built-in metronome initialization.
pub mod init;
/// Cross-thread response and telemetry registry types.
pub mod message;
/// Placeholder endpoint used when a hosted plugin cannot be restored.
pub mod missing_plugin;
/// First-party and externally discovered plugin metadata.
pub mod plugin_catalog;
/// Project-state save feedback routed through the audio feedback channel.
pub mod project_state;
/// FFT device-rate bridge between the DSP engine and the negotiated device rate.
pub mod rate_bridge;
/// Audio-thread-owned render state and plugin snapshots.
pub mod render_state;
/// WAV, FLAC, MP3, and Ogg/Opus export writers.
pub mod writer;

/// Metronome audio file (both downbeat and offbeat)
pub const DOWNBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_downbeat.wav");
/// Embedded metronome offbeat WAV used to construct the built-in click waveform.
pub const OFFBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_offbeat.wav");
