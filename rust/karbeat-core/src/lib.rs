//! # Overview
//!
//! Core Package of Karbeat. Handles the Audio Thread and Business Logic of the App.
//! This package also includes the Core API that is generic and reusable
//! for any kind of UI implementation usage.

#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the API boundary converts validated UI identifiers and intentionally emits best-effort engine notifications"
)]
/// UI-independent project and engine mutation APIs.
pub mod api;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the real-time engine uses bounded sample-domain conversions and non-blocking best-effort channels"
)]
/// Real-time engine, device backend, rendering, telemetry, and export implementation.
pub mod audio;
/// Bounded UI-to-audio commands and audio-to-UI feedback payloads.
pub mod commands;
#[allow(
    clippy::let_underscore_must_use,
    reason = "context broadcasts use non-blocking channels whose disconnected receivers are intentionally ignored"
)]
/// Application-owned project state and communication endpoints.
pub mod context;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "project time and identifier conversions are range-validated by domain operations, and observer broadcasts are best-effort"
)]
/// Persisted project domain, file management, and undo/redo history.
pub mod core;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "startup signal generation converts fixed bounded constants and sends an optional one-shot command"
)]
/// Audio-engine startup and built-in metronome initialization.
pub mod init;
/// Cross-thread response and telemetry registry types.
pub mod message;
/// Re-exported plugin parameter and plugin trait types used by core APIs.
pub mod plugin_types;
#[allow(
    clippy::as_conversions,
    reason = "typed IDs preserve the existing compact integer wire representation"
)]
/// Shared typed identifiers, constants, enums, and bounded scalar types.
pub mod shared;
#[allow(
    clippy::expect_used,
    clippy::panic,
    clippy::unwrap_used,
    reason = "test fixtures use immediate failures to keep invariant violations visible"
)]
/// Test fixtures shared by this crate's unit and integration-style tests.
pub mod test;
/// Audio-buffer utility functions shared by render paths.
pub mod utils;

/// Metronome audio file (both downbeat and offbeat)
pub const DOWNBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_downbeat.wav");
/// Embedded metronome offbeat WAV used to construct the built-in click waveform.
pub const OFFBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_offbeat.wav");
