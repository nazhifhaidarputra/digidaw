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
pub mod api;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the real-time engine uses bounded sample-domain conversions and non-blocking best-effort channels"
)]
pub mod audio;
pub mod commands;
#[allow(
    clippy::let_underscore_must_use,
    reason = "context broadcasts use non-blocking channels whose disconnected receivers are intentionally ignored"
)]
pub mod context;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "project time and identifier conversions are range-validated by domain operations, and observer broadcasts are best-effort"
)]
pub mod core;
#[allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "startup signal generation converts fixed bounded constants and sends an optional one-shot command"
)]
pub mod init;
pub mod message;
pub mod plugin_types;
#[allow(
    clippy::as_conversions,
    reason = "typed IDs preserve the existing compact integer wire representation"
)]
pub mod shared;
#[allow(
    clippy::expect_used,
    clippy::panic,
    clippy::unwrap_used,
    reason = "test fixtures use immediate failures to keep invariant violations visible"
)]
pub mod test;
pub mod utils;

/// Metronome audio file (both downbeat and offbeat)
pub const DOWNBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_downbeat.wav");
pub const OFFBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_offbeat.wav");
