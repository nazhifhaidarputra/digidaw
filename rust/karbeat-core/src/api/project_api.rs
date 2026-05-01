use std::path::Path;

use indexmap::IndexMap;

use crate::audio::exporter::{AudioExportError, TailHandling, export_project as export_project_internal};
use crate::audio::writer::wav::WavAudioWriter;
use crate::audio::writer::{AudioFormat, BitPerSample};
use crate::commands::AudioCommand;
use crate::context::utils::{broadcast_state_change, send_audio_command};
use crate::core::file_manager::project_loader::{load_karbeat_project, save_karbeat_project};
use crate::core::project::{ApplicationState, GeneratorInstanceType};
use crate::core::project::{
    generator::GeneratorInstance, transport::TransportState, ProjectMetadata,
};
use crate::lock::{get_app_read, get_app_write};

pub fn get_project_metadata<T, F>(mapper: F) -> anyhow::Result<T>
where
    F: Fn(&ProjectMetadata) -> T,
{
    let app = get_app_read();
    Ok(mapper(&app.metadata))
}

pub fn get_transport_state<T, F>(mapper: F) -> anyhow::Result<T>
where
    F: Fn(&TransportState) -> T,
{
    let app = get_app_read();
    Ok(mapper(&app.transport))
}

pub fn get_generator_list<C, U, M>(mapper: M) -> anyhow::Result<C>
where
    M: Fn(u32, &GeneratorInstance) -> U,
    C: FromIterator<U>,
{
    let app = get_app_read();
    Ok(app
        .generator_pool
        .iter()
        .map(|(&id, gen)| mapper(id.to_u32(), gen.as_ref()))
        .collect())
}

pub fn get_max_sample_index() -> anyhow::Result<u32> {
    let app = get_app_read();
    Ok(app.max_sample_index)
}

pub fn save_project(path_name: &str) -> anyhow::Result<()> {
    let app = get_app_read();
    save_karbeat_project(Path::new(path_name), &app)?;
    Ok(())
}

pub fn load_project<T, F>(path_name: &str, mapper: F) -> anyhow::Result<T>
where
    F: FnOnce(&ApplicationState) -> T,
{
    // 1. Load the project from disk
    let loaded_app = load_karbeat_project(Path::new(path_name))?;

    // Extract the BPM before we move the loaded app into the global lock
    let bpm = loaded_app.transport.bpm;

    // 2. Halt the audio engine immediately to prevent reading partially overwritten state
    send_audio_command(AudioCommand::StopAndReset);

    // 3. Lock, mutate the global state, and map to the UI DTO
    let mapped_ui_state = {
        let mut app = get_app_write();
        *app = loaded_app;
        mapper(&app)
    };

    // 4. Fire all necessary sync and loading events to the engine/UI
    broadcast_state_change();
    send_audio_command(AudioCommand::SetBPM(bpm));
    let _ = hydrate_live_audio_engine();

    Ok(mapped_ui_state)
}

pub fn export_project<F>(
    output_path: &String,
    sample_rate: u32,
    bit_per_sample: BitPerSample,
    tail_handling: TailHandling,
    progress_callback: F,
) -> anyhow::Result<()>
where
    F: FnMut(f32) -> bool,
{
    let mut app_state = get_app_write();
    let path = Path::new(output_path);

    let is_wav = path
        .extension()
        .map(|ext| ext.to_string_lossy().eq_ignore_ascii_case("wav"))
        .unwrap_or(false);

    if !is_wav {
        return Err(anyhow::anyhow!(
            "Unsupported file format. Currently, only .wav exports are supported."
        ));
    }
    let writer = WavAudioWriter::new(
        path,
        AudioFormat {
            bit_per_sample,
            sample_rate,
            channels: 2,
        },
    )
    .map_err(|e| {
        AudioExportError::new("WriterInit", format!("Failed to create writer: {}", e)).to_string()
    })
    .map_err(|e| anyhow::anyhow!("{}", e))?;

    export_project_internal(
        &mut *app_state,
        output_path,
        sample_rate,
        bit_per_sample,
        writer,
        tail_handling,
        progress_callback,
    )
    .map_err(|e| anyhow::anyhow!("{}", e))?;

    Ok(())
}

/// Create a blank, new, default project. 
pub fn new_blank_project() -> ApplicationState {
    let app = {
        let mut app = get_app_write();
        (&mut app).new_blank_project();
        app.clone()
    };

    // prepare plugin with this new state
    broadcast_state_change();
    send_audio_command(AudioCommand::SetBPM(app.transport.bpm));
    let _ = hydrate_live_audio_engine();

    app
}

/// Safely instantiates all DSP plugins from the current state, 
/// explicitly applies their saved parameters, and sends them to the audio thread.
pub fn hydrate_live_audio_engine() -> anyhow::Result<()> {
    let app = crate::lock::get_app_read();
    let registry = crate::context::ctx().plugin_registry.read();

    let mut generators = IndexMap::new();
    let mut track_effects = IndexMap::new();
    let mut bus_effects = IndexMap::new();
    let mut master_effects = IndexMap::new();

    // 1. Hydrate Generators
    for (gen_id, gen_arc) in &app.generator_pool {
        if let GeneratorInstanceType::Plugin(plugin_instance) = &gen_arc.instance_type {
            if let Some((mut plugin, _)) = registry.create_generator_by_id(plugin_instance.registry_id) {
                for (&param_id, &val) in &plugin_instance.parameters {
                    plugin.set_parameter(param_id, val);
                }
                generators.insert(*gen_id, plugin);
            }
        }
    }

    // 2. Hydrate Track Effects
    for (track_id, channel_arc) in &app.mixer.channels {
        let mut track_chain = IndexMap::new();
        for effect in &channel_arc.effects {
            if let Some((mut plugin, _)) = registry.create_effect_by_id(effect.instance.registry_id) {
                for (&param_id, &val) in &effect.instance.parameters {
                    plugin.set_parameter(param_id, val);
                }
                track_chain.insert(effect.id, plugin);
            }
        }
        if !track_chain.is_empty() {
            track_effects.insert(*track_id, track_chain);
        }
    }

    // 3. Hydrate Bus Effects
    for (bus_id, bus_arc) in &app.mixer.buses {
        let mut bus_chain = IndexMap::new();
        for effect in &bus_arc.channel.effects {
            if let Some((mut plugin, _)) = registry.create_effect_by_id(effect.instance.registry_id) {
                for (&param_id, &val) in &effect.instance.parameters {
                    plugin.set_parameter(param_id, val);
                }
                bus_chain.insert(effect.id, plugin);
            }
        }
        if !bus_chain.is_empty() {
            bus_effects.insert(*bus_id, bus_chain);
        }
    }

    // 4. Hydrate Master Effects
    for effect in &app.mixer.master_bus.effects {
        if let Some((mut plugin, _)) = registry.create_effect_by_id(effect.instance.registry_id) {
            for (&param_id, &val) in &effect.instance.parameters {
                plugin.set_parameter(param_id, val);
            }
            master_effects.insert(effect.id, plugin);
        }
    }

    // Send the fully configured plugins to the Live Audio Engine
    send_audio_command(AudioCommand::PreparePlugin {
        generators,
        track_effects,
        bus_effects,
        master_effects,
    });

    Ok(())
}