use std::path::Path;

use crate::audio::exporter::{AudioExportError, export_project as export_project_internal};
use crate::audio::render_state::broadcast_plugin_state_loading;
use crate::audio::writer::{AudioFormat, BitPerSample};
use crate::audio::writer::wav::WavAudioWriter;
use crate::commands::AudioCommand;
use crate::context::utils::{broadcast_state_change, send_audio_command};
use crate::core::file_manager::project_loader::{load_karbeat_project, save_karbeat_project};
use crate::core::project::ApplicationState;
use crate::lock::{get_app_read, get_app_write};
use crate::core::project::{ProjectMetadata, transport::TransportState, generator::GeneratorInstance};

pub fn get_project_metadata<T, F>(mapper: F) -> anyhow::Result<T>
where F: Fn(&ProjectMetadata) -> T {
    let app = get_app_read();
    Ok(mapper(&app.metadata))
}

pub fn get_transport_state<T, F>(mapper: F) -> anyhow::Result<T>
where F: Fn(&TransportState) -> T {
    let app = get_app_read();
    Ok(mapper(&app.transport))
}

pub fn get_generator_list<C, U, M>(mapper: M) -> anyhow::Result<C>
where 
    M: Fn(u32, &GeneratorInstance) -> U, 
    C: FromIterator<U> 
{
    let app = get_app_read();
    Ok(app.generator_pool.iter().map(|(&id, gen)| mapper(id.to_u32(), gen.as_ref())).collect())
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
    broadcast_plugin_state_loading();

    Ok(mapped_ui_state)
}

pub fn export_project<F>(
    output_path: &String,
    sample_rate: u32,
    bit_per_sample: BitPerSample,
    progress_callback: F,
) -> anyhow::Result<()> where F:FnMut(f32) -> bool {
    let mut app_state = get_app_write();
    let path = Path::new(output_path);
    let writer = WavAudioWriter::new(path, AudioFormat {
        bit_per_sample,
        sample_rate,
        channels: 2,
    }).map_err(|e|
        AudioExportError::new("WriterInit", format!("Failed to create writer: {}", e)).to_string()
    ).map_err(|e| anyhow::anyhow!("{}", e))?;

    export_project_internal(&mut *app_state, output_path, sample_rate, bit_per_sample, writer, progress_callback
    ).map_err(|e| anyhow::anyhow!("{}", e))?;

    Ok(())
}