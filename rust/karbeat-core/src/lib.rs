//! # Overview
//!
//! Core Package of Karbeat. Handles the Audio Thread and Business Logic of the App.
//! This package also includes the Core API that is generic and reusable
//! for any kind of UI implementation usage.

pub mod api;
pub mod audio;
pub mod commands;
pub mod context;
pub mod core;
pub mod init;
pub mod message;
pub mod plugin_types;
pub mod shared;
pub mod test;
pub mod utils;

/// Metronome audio file (both downbeat and offbeat)
pub const DOWNBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_downbeat.wav");
pub const OFFBEAT_BYTES: &'static [u8] =
    include_bytes!("../../../assets/audio/metronome_offbeat.wav");
