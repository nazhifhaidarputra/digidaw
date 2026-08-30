use crate::context::DawContext;

pub mod audio_api;
pub mod audio_settings_api;
pub mod audio_waveform_api;
pub mod automation_api;
pub mod clip_api;
pub mod clipboard_api;
pub mod error;
pub mod mixer_api;
pub mod monitor_api;
pub mod note_api;
pub mod pattern_api;
pub mod plugin_api;
pub mod project_api;
pub mod track_api;
pub mod transport_api;

pub fn undo(ctx: &mut DawContext) -> Result<(), String> {
    ctx.history.undo(&mut ctx.app_state)?;
    ctx.broadcast_full_graph();
    Ok(())
}

pub fn redo(ctx: &mut DawContext) -> Result<(), String> {
    ctx.history.redo(&mut ctx.app_state)?;
    ctx.broadcast_full_graph();
    Ok(())
}

pub fn history_limit(ctx: &DawContext) -> usize {
    ctx.history.max_history
}

pub fn set_history_limit(ctx: &mut DawContext, limit: usize) -> anyhow::Result<usize> {
    ctx.history.set_max_history(limit)?;
    Ok(ctx.history.max_history)
}
