use std::path::Path;

use crate::audio::exporter::{TailHandling, export_project as export_project_internal};

use crate::audio::writer::AudioExportConfig;
use crate::commands::AudioCommand;
use crate::context::DawContext;
use crate::core::file_manager::project_loader::load_daw_project;
use crate::core::project::ApplicationState;
use crate::core::project::{
    ProjectMetadata, generator::GeneratorInstance, transport::TransportState,
};
/// Maps the current project's metadata without cloning unrelated project state.
pub fn get_project_metadata<T, F>(ctx: &DawContext, mapper: F) -> anyhow::Result<T>
where
    F: Fn(&ProjectMetadata) -> T,
{
    Ok(mapper(&ctx.app_state.metadata))
}

/// Replaces project metadata, records history, and leaves audio-only state unchanged.
pub fn update_project_metadata(
    ctx: &mut DawContext,
    metadata: ProjectMetadata,
) -> anyhow::Result<ProjectMetadata> {
    let metadata = metadata.normalize_and_validate()?;
    ctx.app_state.metadata = metadata.clone();
    Ok(metadata)
}

/// Maps the serialized project transport state.
pub fn get_transport_state<T, F>(ctx: &DawContext, mapper: F) -> anyhow::Result<T>
where
    F: Fn(&TransportState) -> T,
{
    Ok(mapper(&ctx.app_state.transport))
}

/// Maps every project generator instance into a caller-selected collection.
pub fn get_generator_list<C, U, M>(ctx: &DawContext, mapper: M) -> anyhow::Result<C>
where
    M: Fn(u64, &GeneratorInstance) -> U,
    C: FromIterator<U>,
{
    Ok(ctx
        .app_state
        .generator_pool
        .iter()
        .map(|(id, generator)| mapper(id.to_u64(), generator))
        .collect())
}

mod restore;
mod save;
pub(crate) use save::hosted_instance;

/// Synchronizes live engine values, captures hosted state, and atomically saves the project.
pub fn save_project(ctx: &mut DawContext, path_name: &str) -> anyhow::Result<()> {
    let host_state_capture = ctx.host_state_capture.clone();
    save::save_project(
        ctx,
        Path::new(path_name),
        std::time::Duration::from_secs(2),
        move |identity, instance| host_state_capture.capture_state(identity, instance),
    )
}

/// Loads and migrates a project, restores runtime resources, hydrates the engine, and maps it.
pub fn load_project<T, F>(ctx: &mut DawContext, path_name: &str, mapper: F) -> anyhow::Result<T>
where
    F: FnOnce(&ApplicationState) -> T,
{
    let sample_rate = ctx.audio_runtime_settings.read().requested_dsp.sample_rate;
    let mut loaded = load_daw_project(Path::new(path_name), sample_rate)?;
    loaded.audio_config = ctx.app_state.audio_config.clone();
    loaded.clipboard = ctx.app_state.clipboard.clone();
    if restore::has_external(&loaded) || restore::has_external(&ctx.app_state) {
        restore::replace(ctx, loaded)?;
    } else {
        ctx.send_audio_command(AudioCommand::StopAndReset)
            .or_else(|error| {
                if ctx.command_sender.lock().is_none() {
                    Ok(())
                } else {
                    Err(error)
                }
            })?;
        ctx.app_state = loaded;
        ctx.broadcast_full_graph();
        if ctx.command_sender.lock().is_some() {
            ctx.send_audio_command(AudioCommand::SetBPM(ctx.app_state.transport.bpm))?;
            hydrate_live_audio_engine(ctx)?;
        }
    }
    Ok(mapper(&ctx.app_state))
}

/// Renders the current project through an offline engine snapshot and reports export progress.
pub fn export_project<F>(
    ctx: &mut DawContext,
    output_path: &str,
    config: AudioExportConfig,
    tail_handling: TailHandling,
    progress_callback: F,
) -> anyhow::Result<()>
where
    F: FnMut(f32) -> bool + Send,
{
    export_project_internal(ctx, output_path, config, tail_handling, progress_callback)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    Ok(())
}

/// Create a blank, new, default project.
/// Replaces project state with a blank project and fully rehydrates audio-thread state.
pub fn new_blank_project(ctx: &mut DawContext) -> anyhow::Result<ApplicationState> {
    let mut staged = ctx.app_state.clone();
    staged.new_blank_project();
    if restore::has_external(&ctx.app_state) {
        restore::replace(ctx, staged)?;
    } else {
        ctx.app_state = staged;
        ctx.broadcast_full_graph();
        if ctx.command_sender.lock().is_some() {
            ctx.send_audio_command(AudioCommand::SetBPM(ctx.app_state.transport.bpm))?;
            hydrate_live_audio_engine(ctx)?;
        }
    }
    Ok(ctx.app_state.clone())
}

/// Rebuilds and publishes plugins, mixer values, routing, transport, and graph state.
pub fn hydrate_live_audio_engine(ctx: &mut DawContext) -> anyhow::Result<()> {
    if restore::has_external(&ctx.app_state) {
        return restore::replace(ctx, ctx.app_state.clone());
    }
    if ctx.command_sender.lock().is_none() {
        return Ok(());
    }
    let dsp = ctx.audio_runtime_settings.read().requested_dsp;
    let command = restore::hydration_command(
        &ctx.app_state,
        &ctx.plugin_registry,
        &ctx.external_plugin_failures,
        dsp.sample_rate,
        dsp.block_size as usize,
    );
    ctx.send_audio_command(command)
}
