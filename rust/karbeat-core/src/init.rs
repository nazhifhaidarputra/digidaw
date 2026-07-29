// ==================================================================
// ================== Functions =====================================
// ==================================================================

use std::{path::PathBuf, sync::Arc};

use memmap2::MmapOptions;
use parking_lot::Mutex;
use rtrb::RingBuffer;

use crate::{
    audio::backend::{start_audio_stream, AudioDeviceConfig},
    commands::AudioCommand,
    context::DawContext,
    core::project::AudioWaveform,
};

fn generate_startup_beep() -> Option<AudioWaveform> {
    let sample_rate = 48000;
    let duration_secs = 0.5;
    let total_frames = ((sample_rate as f32) * duration_secs) as usize;
    let frequency = 440.0; // A4 Note

    let mut buffer = Vec::with_capacity(total_frames * 2); // Stereo

    for i in 0..total_frames {
        let t = (i as f32) / (sample_rate as f32);
        let signal = (t * frequency * 2.0 * std::f32::consts::PI).sin();
        let envelope = 1.0 - (i as f32) / (total_frames as f32);

        let final_sample = signal * envelope * 0.3;

        buffer.push(final_sample); // Left
        buffer.push(final_sample); // Right
    }

    let byte_slice: &[u8] = bytemuck::cast_slice(&buffer);
    let mmap_mut = match MmapOptions::new().len(byte_slice.len()).map_anon() {
        Ok(mut m) => {
            m.copy_from_slice(byte_slice);
            m
        }
        Err(e) => {
            log::warn!("Startup beep skipped: failed to allocate anonymous mmap: {e}");
            return None;
        }
    };

    let mmap = match mmap_mut.make_read_only() {
        Ok(m) => m,
        Err(e) => {
            log::warn!("Startup beep skipped: failed to make mmap read-only: {e}");
            return None;
        }
    };

    Some(AudioWaveform {
        buffer: Some(Arc::new(mmap)),
        file_path: PathBuf::from("internal_beep"),
        sample_rate,
        channels: 2,
        duration: duration_secs as f64,
        trim_end: total_frames as u32,
        ..Default::default()
    })
}

pub fn init_engine(ctx: &mut DawContext) {
    let device_conf = AudioDeviceConfig::default();

    // Capacity 128 is plenty for manual clicks
    let (cmd_prod, cmd_cons) = RingBuffer::new(128);

    // Store Producer in context
    ctx.command_sender = Mutex::new(Some(cmd_prod));

    match start_audio_stream(ctx, cmd_cons, device_conf) {
        Ok(_) => {
            log::info!("Audio Engine Successfully initialized");

            // SEND STARTUP BEEP
            if let Some(beep_waveform) = generate_startup_beep() {
                // Borrow the sender safely via as_mut() without locks
                if let Some(producer) = ctx.command_sender.lock().as_mut() {
                    let _ = producer.push(AudioCommand::PlayOneShot(beep_waveform));
                    log::info!("Startup beep command sent");
                }
            }
        }
        Err(e) => {
            log::error!("Failed to start audio engine: {}", e);
            panic!()
        }
    }
}
