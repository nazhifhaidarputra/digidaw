// src/core/file_manager/loader.rs

// Source code of file loader

use hashbrown::HashMap;
use karbeat_utils::audio_utils::resample_interleaved_stream;
use std::{
    fs::File,
    io::{BufReader, BufWriter, Write},
    path::Path,
    sync::Arc,
};
use tempfile::tempfile;

use anyhow::{Context, Result, anyhow};
use memmap2::MmapOptions;
use rodio::Source;

use crate::core::project::{ApplicationState, AudioSourceId, track::audio_waveform::AudioWaveform};

trait FileNameExt {
    fn file_name_string(&self) -> String;
}

impl FileNameExt for Path {
    fn file_name_string(&self) -> String {
        self.file_name()
            .and_then(|s| s.to_str())
            .unwrap_or("untitled")
            .to_string()
    }
}

mod err {
    use thiserror::Error;

    #[derive(Error, Debug)]
    #[error("Failed to load the audio: {message}")]
    #[allow(dead_code)]
    // TODO: Use this in Audio File I/O
    pub struct LoadAudioError<'a> {
        pub message: &'a str,
    }
}

/// Main entry point for loading audio.
pub fn load_audio_file(
    path_str: &str,
    name: Option<&str>,
    target_sample_rate: u32,
) -> Result<AudioWaveform> {
    let path = Path::new(path_str);
    let file =
        File::open(path).with_context(|| format!("Failed to open audio file: {}", path_str))?;
    let reader = BufReader::new(file);

    let mut decoder =
        rodio::Decoder::new(reader).context("Failed to decode audio file (unsupported format)")?;
    let sample_rate = decoder.sample_rate().get();
    let source_sample_rate = decoder.sample_rate().get();
    let channels_u16 = decoder.channels().get();
    let channels = channels_u16 as usize;

    // Cache the loaded audio file
    // let mut f32_decoder = decoder.into_iter();
    let mut cache_file = tempfile().context("Failed to create temporary cache file")?;

    // Use a BufWriter. It handles disk I/O incredibly efficiently behind the scenes.
    let total_samples = {
        let mut writer = BufWriter::new(&mut cache_file);

        let written = if source_sample_rate == target_sample_rate {
            stream_raw_to_disk(&mut decoder, &mut writer)?
        } else {
            resample_interleaved_stream(
                &mut decoder,
                source_sample_rate,
                target_sample_rate,
                channels,
                &mut writer,
            )
            .map_err(|e| anyhow!("Failed to resample stream: {}", e.err_source))?
        };

        writer.flush()?;
        written
    };

    let total_frames = if channels > 0 {
        total_samples / (channels as u32)
    } else {
        0
    };

    // Write the raw f32 bytes directly to the disk cache
    // bytemuck safely casts &[f32] into &[u8] for writing
    // let byte_slice: &[u8] = bytemuck::cast_slice(&all_samples);
    // cache_file.write_all(byte_slice)?;

    let mmap = unsafe { MmapOptions::new().map(&cache_file)? };

    let duration_seconds = if sample_rate > 0 {
        (total_frames as f64) / (sample_rate as f64)
    } else {
        0.0
    };

    let final_name = if let Some(name_str) = name {
        name_str.to_string()
    } else {
        path.file_name_string()
    };

    let buffer = Some(Arc::new(mmap));

    Ok(AudioWaveform {
        buffer,
        file_path: path.to_path_buf(),
        name: final_name,
        sample_rate: target_sample_rate,
        channels: channels_u16,
        duration: duration_seconds,
        trim_end: total_frames,
        ..Default::default()
    })
}

/// Helper for the fast-path: Streams decoded audio directly to disk without resampling.
fn stream_raw_to_disk<I, W>(decoder: &mut I, writer: &mut W) -> Result<u32>
where
    I: Iterator<Item = f32>,
    W: Write,
{
    let chunk_size = 8192;
    let mut chunk = Vec::with_capacity(chunk_size);
    let mut total_written = 0;

    for sample in decoder {
        chunk.push(sample);
        total_written += 1;

        if chunk.len() == chunk_size {
            writer.write_all(bytemuck::cast_slice(&chunk))?;
            chunk.clear();
        }
    }

    if !chunk.is_empty() {
        writer.write_all(bytemuck::cast_slice(&chunk))?;
    }

    Ok(total_written)
}

// Trait AudioLoader
pub trait AudioLoader {
    fn load_audio(
        &mut self,
        path: &str,
        name: Option<&str>,
        target_sample_rate: u32,
    ) -> Result<AudioSourceId>;
    fn get_audio_source(&self, id: &AudioSourceId) -> Option<Arc<AudioWaveform>>;
    fn get_audio_sources(&self) -> HashMap<AudioSourceId, Arc<AudioWaveform>>;
}

impl AudioLoader for ApplicationState {
    fn load_audio(
        &mut self,
        path: &str,
        name: Option<&str>,
        target_sample_rate: u32,
    ) -> Result<AudioSourceId> {
        // Load the actual audio data (Heavy I/O operation)
        // This parses the file into f32 samples
        let mut waveform = match load_audio_file(path, name, target_sample_rate) {
            Ok(waveform) => waveform,
            Err(e) => {
                let error_msg = format!("Cannot decode audio file: {}", e);
                log::error!("{}", error_msg);
                anyhow::bail!("{}", error_msg);
            }
        };

        let asset_library = &mut self.asset_library;
        let source_id = asset_library.source_map.insert_with_key(|id| {
            waveform.id = Some(id);
            Arc::new(waveform)
        });

        log::info!("Successfully loaded audio: {} (ID: {})", path, source_id);

        Ok(source_id)
    }

    fn get_audio_source(&self, id: &AudioSourceId) -> Option<Arc<AudioWaveform>> {
        self.asset_library.source_map.get(*id).cloned()
    }

    fn get_audio_sources(&self) -> HashMap<AudioSourceId, Arc<AudioWaveform>> {
        self.asset_library
            .source_map
            .iter()
            .map(|(id, waveform)| (id, waveform.clone()))
            .collect()
    }
}
