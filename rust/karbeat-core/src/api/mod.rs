use crate::context::DawContext;

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
/// Track lookup, creation, metadata, ordering, and deletion APIs.
pub mod track_api;
/// Playback, looping, tempo, playhead, and pattern transport APIs.
pub mod transport_api;

/// Applies the most recent reversible project action and replaces the audio-thread graph.
///
/// The history mutation completes before the full graph snapshot is broadcast. A history error
/// leaves the audio graph untouched and is returned as a string.
pub fn undo(ctx: &mut DawContext) -> Result<(), String> {
    ctx.history.undo(&mut ctx.app_state)?;
    ctx.broadcast_full_graph();
    Ok(())
}

/// Reapplies the most recently undone project action and replaces the audio-thread graph.
pub fn redo(ctx: &mut DawContext) -> Result<(), String> {
    ctx.history.redo(&mut ctx.app_state)?;
    ctx.broadcast_full_graph();
    Ok(())
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
