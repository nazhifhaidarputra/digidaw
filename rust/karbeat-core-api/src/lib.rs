//! # Overview
//!
//! Core API layer of Karbeat. Sits between the core modules and UI bridges such as the
//! Flutter FFI crate, and is generic and reusable for any kind of UI implementation.
#![allow(
    clippy::as_conversions,
    clippy::let_underscore_must_use,
    reason = "the API boundary converts validated UI identifiers and intentionally emits best-effort engine notifications"
)]

use karbeat_core::{context::DawContext, core::history::HistoryError};

/// Tempo fitting and offline renders of audio sources.
pub mod audio_analysis_api;
/// Playback previews, MIDI auditioning, transport feedback, and audio configuration access.
pub mod audio_api;
/// Runtime output-device and DSP configuration APIs.
pub mod audio_settings_api;
/// Audio-source import and waveform lookup APIs.
pub mod audio_waveform_api;
/// Automation lane, point, modulation source, and link APIs.
pub mod automation_api;
/// Clip creation, editing, slicing, duplication, and deletion APIs.
pub mod clip_api;
/// Note and clip clipboard APIs.
pub mod clipboard_api;
/// UI-facing structured error types.
pub mod error;
/// Lifecycle and control APIs for externally hosted plugins.
pub mod external_plugin_api;
/// Background job manager for renders, analysis, plugin lifecycle and scans.
pub mod jobs;
/// Auto save, unsaved-change status, recovery, and crash report APIs.
pub mod mitigation_api;
/// Mixer channels, effects, buses, routing, telemetry, and sidechain APIs.
pub mod mixer_api;
/// Process and memory performance monitoring APIs.
pub mod monitor_api;
/// MIDI note editing and batch-operation APIs.
pub mod note_api;
/// MIDI pattern lookup, naming, and preview APIs.
pub mod pattern_api;
/// Internal and hosted plugin lookup, parameter, command, and telemetry APIs.
pub mod plugin_api;
/// External plugin discovery, scanning, caching, and cancellation APIs.
pub mod plugin_discovery_api;
/// Project metadata, persistence, export, initialization, and hydration APIs.
pub mod project_api;
#[allow(
    clippy::expect_used,
    clippy::panic,
    clippy::unwrap_used,
    reason = "test fixtures use immediate failures to keep invariant violations visible"
)]
/// Test fixtures shared by this crate's unit and integration-style tests.
pub mod test;
/// Track lookup, creation, metadata, ordering, and deletion APIs.
pub mod track_api;
/// Playback, looping, tempo, playhead, and pattern transport APIs.
pub mod transport_api;

/// Reverts the most recent history step and republishes what it changed to the audio thread.
///
/// A failing step leaves the project partly reverted, so the history is cleared and the whole
/// graph is republished before the error is returned.
pub fn undo(ctx: &mut DawContext) -> Result<(), String> {
    let result = ctx.history.undo(&mut ctx.app_state);
    finish_history_step(ctx, result)
}

/// Reapplies the most recently undone history step and republishes what it changed.
pub fn redo(ctx: &mut DawContext) -> Result<(), String> {
    let result = ctx.history.redo(&mut ctx.app_state);
    finish_history_step(ctx, result)
}

fn finish_history_step(
    ctx: &mut DawContext,
    result: Result<
        karbeat_core::core::history::EngineSync,
        karbeat_core::core::history::HistoryError,
    >,
) -> Result<(), String> {
    match result {
        Ok(sync) => {
            ctx.mark_project_modified();
            ctx.apply_engine_sync(sync);
            Ok(())
        }
        Err(error @ (HistoryError::NothingToUndo | HistoryError::NothingToRedo)) => {
            Err(error.to_string())
        }
        Err(error) => {
            ctx.mark_project_modified();
            ctx.broadcast_full_graph();
            Err(error.to_string())
        }
    }
}

/// Returns the maximum number of undoable actions retained by the project history.
pub fn history_limit(ctx: &DawContext) -> usize {
    ctx.history.max_history
}

/// Changes the history capacity and returns the effective stored limit after validation.
pub fn set_history_limit(ctx: &mut DawContext, limit: usize) -> anyhow::Result<usize> {
    ctx.history.set_max_history(limit)?;
    Ok(ctx.history.max_history)
}
