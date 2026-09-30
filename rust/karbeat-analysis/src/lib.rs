//! # Overview
//!
//! Music analysis for Karbeat. Detects tempo, beats and downbeats with the
//! [Beat This!](https://github.com/CPJKU/beat_this) model through the `beat-this` crate, on
//! the pure-Rust `rten` runtime. Long audio is analyzed in segments on several threads at
//! once, as many as the device's free memory allows.
#![allow(
    clippy::as_conversions,
    reason = "audio positions convert between sample counts and seconds"
)]

/// How many segments run at once, from free memory and threads.
pub mod budget;
mod model;
/// Segmented tempo analysis and model lifetime.
pub mod tempo;

pub use budget::{AnalysisPlan, DeviceResources, PARALLEL_MIN_SECONDS};
pub use tempo::{
    AudioInput, ModelPaths, TempoAnalysis, analyze_tempo, configure_models, release_models_if_idle,
};

/// Why tempo analysis did not produce a result.
#[derive(Debug, Clone, PartialEq, thiserror::Error)]
pub enum AnalysisError {
    #[error("tempo analysis was cancelled")]
    Cancelled,
    #[error("tempo analysis models are unavailable: {0}")]
    ModelsUnavailable(String),
    #[error(
        "not enough free memory for tempo analysis: needs about {required_mb} MB, {available_mb} MB free"
    )]
    InsufficientMemory { required_mb: u64, available_mb: u64 },
    #[error("tempo analysis failed: {0}")]
    Inference(String),
    #[error("no beats were detected")]
    NoBeats,
    #[error("{0}")]
    InvalidInput(&'static str),
}
