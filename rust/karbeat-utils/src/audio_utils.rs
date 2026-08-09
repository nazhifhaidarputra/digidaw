use std::io::Write;

use dasp::slice;
use rubato::{
    audioadapter_buffers::direct::{InterleavedSlice, SequentialSlice},
    Async, FixedAsync, Indexing, Resampler, SincInterpolationParameters, SincInterpolationType,
    WindowFunction,
};

use crate::error::AudioResamplingError;

const CHUNK_SIZE: usize = 8192;
const SINC_LEN: usize = 64;
const OVERSAMPLING_FACTOR: usize = 64;

/// Robust Stereo Downsampling (Min-Max Binning) with Dasp.
/// Supports generic Mono (1) or Stereo (2) channel counts safely.
///
/// Output Format per bin: [Left_Min, Left_Max, Right_Min, Right_Max]
pub fn downsample(buffer: &[f32], channels: usize, target_bins: usize) -> Vec<f32> {
    if buffer.is_empty() || channels == 0 || target_bins == 0 {
        return Vec::new();
    }

    let mut out = Vec::with_capacity(target_bins * 4);

    if channels == 1 {
        // DASP: Safely cast flat slice to Mono frames without allocation
        let frames: &[[f32; 1]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let total_frames = frames.len();

        // Handle tiny buffers by padding directly to the output
        if total_frames <= target_bins {
            for frame in frames {
                let val = frame[0];
                out.push(val);
                out.push(val); // L min/max
                out.push(val);
                out.push(val); // R min/max
            }
            return out;
        }

        let frames_per_bin = total_frames / target_bins;

        for bin_idx in 0..target_bins {
            let start_frame = bin_idx * frames_per_bin;
            // Ensure the very last bin absorbs any remainder frames
            let end_frame = if bin_idx == target_bins - 1 {
                total_frames
            } else {
                start_frame + frames_per_bin
            };

            let mut min_val = 1.0f32;
            let mut max_val = -1.0f32;

            for i in start_frame..end_frame {
                let val = frames[i][0];
                if val < min_val {
                    min_val = val;
                }
                if val > max_val {
                    max_val = val;
                }
            }

            if min_val > max_val {
                min_val = 0.0;
                max_val = 0.0;
            }

            // Duplicate mono signal to Left and Right
            out.push(min_val);
            out.push(max_val);
            out.push(min_val);
            out.push(max_val);
        }
    } else {
        // DASP: Safely cast flat slice to Stereo frames
        let frames: &[[f32; 2]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let total_frames = frames.len();

        if total_frames <= target_bins {
            for frame in frames {
                out.push(frame[0]);
                out.push(frame[0]);
                out.push(frame[1]);
                out.push(frame[1]);
            }
            return out;
        }

        let frames_per_bin = total_frames / target_bins;

        for bin_idx in 0..target_bins {
            let start_frame = bin_idx * frames_per_bin;
            let end_frame = if bin_idx == target_bins - 1 {
                total_frames
            } else {
                start_frame + frames_per_bin
            };

            let mut min_l = 1.0f32;
            let mut max_l = -1.0f32;
            let mut min_r = 1.0f32;
            let mut max_r = -1.0f32;

            for i in start_frame..end_frame {
                let l = frames[i][0];
                let r = frames[i][1];

                if l < min_l {
                    min_l = l;
                }
                if l > max_l {
                    max_l = l;
                }
                if r < min_r {
                    min_r = r;
                }
                if r > max_r {
                    max_r = r;
                }
            }

            if min_l > max_l {
                min_l = 0.0;
                max_l = 0.0;
                min_r = 0.0;
                max_r = 0.0;
            }

            out.push(min_l);
            out.push(max_l);
            out.push(min_r);
            out.push(max_r);
        }
    }

    out
}

/// Quantize f32 [-1.0, 1.0] → i8 [-127, 127]
pub fn quantize_to_i8(input: &[f32]) -> Vec<i8> {
    input
        .iter()
        .map(|&v| {
            let clamped = v.clamp(-1.0, 1.0);
            (clamped * 127.0) as i8
        })
        .collect()
}

/// Downsample using max absolute value (preserves peaks)
pub fn downsample_max_abs(input: &[i8], _chunk_size: usize) -> Vec<i8> {
    input
        .chunks(CHUNK_SIZE)
        .map(|chunk| chunk.iter().copied().max_by_key(|v| v.abs()).unwrap_or(0))
        .collect()
}

/// Create mip maps for waveform buffer
/// This includes 1 sample per bin, 4 samples per bin, 16 samples per bin,
/// 64 samples per bin, 256 samples per bin, 1024 samples per bin, each sample/bin
/// mapped as HashMap key
pub fn setup_mipmaps(buffer: &[f32], channels: usize) -> hashbrown::HashMap<u32, Vec<i8>> {
    let mut mipmaps = hashbrown::HashMap::new();

    if buffer.is_empty() || channels == 0 {
        return mipmaps;
    }

    let total_frames = buffer.len() / channels;

    // Mipmap levels (samples per bin)
    let levels = [1, 4, 16, 64, 256, 1024];

    for &samples_per_bin in &levels {
        // Compute number of bins for this mip level
        let target_bins = (total_frames / samples_per_bin).max(1);

        // Step 1: downsample (min/max binning, f32)
        let downsampled_f32 = downsample(buffer, channels, target_bins);

        // Step 2: quantize → i8
        let quantized = quantize_to_i8(&downsampled_f32);

        mipmaps.insert(samples_per_bin as u32, quantized);
    }

    mipmaps
}

pub fn find_best_mipmap(
    mipmaps: &hashbrown::HashMap<u32, Vec<i8>>,
    target: u32,
) -> Option<&Vec<i8>> {
    mipmaps
        .iter()
        .filter(|(k, _)| **k >= target)
        .min_by_key(|(k, _)| *k)
        .or_else(|| {
            // fallback to largest available
            mipmaps.iter().max_by_key(|(k, _)| *k)
        })
        .map(|(_, v)| v)
}

// ===============================================
// RESAMPLER
// ===============================================

/// Resample a non-interleaved buffer using Rubato's high-quality Sinc interpolator.
/// `buffer` expects an array of slices, where each slice is a discrete channel (e.g. [Left, Right]).
pub fn resample_buffers(
    buffer: &[&[f32]],
    channels: usize,
    source_sample_rate: u32,
    target_sample_rate: u32,
) -> Result<Vec<Vec<f32>>, AudioResamplingError> {
    if buffer.is_empty() || channels == 0 || source_sample_rate == target_sample_rate {
        return Ok(buffer.iter().map(|ch| ch.to_vec()).collect());
    }

    let ratio = target_sample_rate as f64 / source_sample_rate as f64;

    let params = SincInterpolationParameters {
        sinc_len: SINC_LEN,
        f_cutoff: None,
        interpolation: SincInterpolationType::Cubic,
        oversampling_factor: OVERSAMPLING_FACTOR,
        window: WindowFunction::BlackmanHarris2,
    };

    let mut resampler = Async::<f32>::new_sinc(
        ratio,
        2.0, // Max expected ratio (e.g., downsampling from 96k to 44.1k is fine, or up to 88.2k)
        &params,
        CHUNK_SIZE,
        channels,
        FixedAsync::Output,
    )
    .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

    let total_in_frames = buffer[0].len();
    let expected_out_frames = (total_in_frames as f64 * ratio).ceil() as usize;
    let mut out: Vec<Vec<f32>> = vec![Vec::with_capacity(expected_out_frames); channels];

    let mut indata = vec![0.0; channels * resampler.input_frames_max()];
    let mut outdata = vec![0.0; channels * resampler.output_frames_max()];
    let outdata_capacity = resampler.output_frames_max();

    let indexing = Indexing::new();
    let mut frames_processed = 0;

    while frames_processed < total_in_frames {
        let frames_to_read = resampler.input_frames_next();
        let available = total_in_frames - frames_processed;
        let actual_read = frames_to_read.min(available);

        // Populate the flat Sequential buffer (LLLL... RRRR...)
        for ch in 0..channels {
            let start_idx = ch * frames_to_read;

            indata[start_idx..start_idx + actual_read]
                .copy_from_slice(&buffer[ch][frames_processed..frames_processed + actual_read]);

            // Pad with zeros if it's the final partial chunk
            if actual_read < frames_to_read {
                indata[start_idx + actual_read..start_idx + frames_to_read].fill(0.0);
            }
        }

        // Wrap the flat slices in the audioadapter Sequential structs required by Rubato
        let input_adapter = SequentialSlice::new(
            &indata[..channels * frames_to_read],
            channels,
            frames_to_read,
        )
        .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let mut output_adapter = SequentialSlice::new_mut(&mut outdata, channels, outdata_capacity)
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        // Process the buffers
        let (_frames_read, frames_written) = resampler
            .process_into_buffer(&input_adapter, &mut output_adapter, Some(&indexing))
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        // Extract from the flat Sequential buffer back into our Vec<Vec<f32>> output
        for ch in 0..channels {
            let start_idx = ch * outdata_capacity;
            out[ch].extend_from_slice(&outdata[start_idx..start_idx + frames_written]);
        }

        frames_processed += actual_read;
    }

    // Because we padded the final chunk with zeros, truncate it down to exact expected size
    for ch in 0..channels {
        out[ch].truncate(expected_out_frames);
    }

    Ok(out)
}

/// Resample an interleaved audio buffer (e.g., [L, R, L, R, ...]).
/// Utilizes the audioadapter_buffers crate to directly map the memory for rubato.
pub fn resample_interleaved_buffer(
    buffer: &[f32],
    channels: usize,
    source_sample_rate: u32,
    target_sample_rate: u32,
) -> Result<Vec<f32>, AudioResamplingError> {
    if buffer.is_empty() || channels == 0 {
        return Ok(Vec::new());
    }

    if source_sample_rate == target_sample_rate {
        return Ok(buffer.to_vec());
    }

    let ratio = target_sample_rate as f64 / source_sample_rate as f64;

    let params = SincInterpolationParameters {
        sinc_len: SINC_LEN,
        f_cutoff: None,
        interpolation: SincInterpolationType::Cubic,
        oversampling_factor: OVERSAMPLING_FACTOR,
        window: WindowFunction::BlackmanHarris2,
    };

    let mut resampler =
        Async::<f32>::new_sinc(ratio, 2.0, &params, CHUNK_SIZE, channels, FixedAsync::Input)
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

    // Reusable buffers for a single chunk, assuming interleaved samples
    let mut indata = vec![0.0; channels * CHUNK_SIZE];
    let mut outdata = vec![0.0; channels * resampler.output_frames_max()];
    let outdata_capacity = outdata.len() / channels;

    let indexing = Indexing::new();

    let total_frames = buffer.len() / channels;
    let mut final_out = Vec::with_capacity((buffer.len() as f64 * ratio).ceil() as usize);
    let mut frames_processed = 0;

    // Keep processing for as long as there is more audio to handle
    loop {
        if frames_processed >= total_frames {
            break;
        }

        let frames_to_read = resampler.input_frames_next();
        let available = total_frames - frames_processed;
        let actual_read = frames_to_read.min(available);

        let start_idx = frames_processed * channels;
        let end_idx = start_idx + (actual_read * channels);

        // Fetch the next chunk of frames into `indata`.
        indata[..actual_read * channels].copy_from_slice(&buffer[start_idx..end_idx]);

        // If it's a shorter final chunk, pad with zeros
        if actual_read < frames_to_read {
            indata[actual_read * channels..frames_to_read * channels].fill(0.0);
        }

        let input_adapter = InterleavedSlice::new(&indata, channels, frames_to_read)
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let mut output_adapter =
            InterleavedSlice::new_mut(&mut outdata, channels, outdata_capacity)
                .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let (_frames_read, frames_written) = resampler
            .process_into_buffer(&input_adapter, &mut output_adapter, Some(&indexing))
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        // Write the `frames_written` output frames to the destination buffer
        final_out.extend_from_slice(&outdata[..frames_written * channels]);

        frames_processed += actual_read;
    }

    Ok(final_out)
}

/// Resample an interleaved audio stream directly into a generic writer.
/// Ideal for low-RAM disk streaming or real-time network streams.
pub fn resample_interleaved_stream<I, W>(
    decoder: &mut I,
    source_sample_rate: u32,
    target_sample_rate: u32,
    channels: usize,
    writer: &mut W,
) -> Result<u32, AudioResamplingError>
where
    I: Iterator<Item = f32>,
    W: Write,
{
    if channels == 0 {
        return Ok(0);
    }

    let ratio = target_sample_rate as f64 / source_sample_rate as f64;

    let params = SincInterpolationParameters {
        sinc_len: SINC_LEN,
        f_cutoff: None,
        interpolation: SincInterpolationType::Cubic,
        oversampling_factor: OVERSAMPLING_FACTOR,
        window: WindowFunction::BlackmanHarris2,
    };

    let mut resampler = Async::<f32>::new_sinc(
        ratio,
        2.0, // Max expected ratio
        &params,
        CHUNK_SIZE,
        channels,
        FixedAsync::Input,
    )
    .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

    let mut indata = vec![0.0; channels * CHUNK_SIZE];
    let mut outdata = vec![0.0; channels * resampler.output_frames_max()];
    let outdata_capacity = outdata.len() / channels;
    let indexing = Indexing::new();
    
    let mut total_written_samples: u32 = 0;

    loop {
        let frames_to_read = resampler.input_frames_next();
        let samples_to_read = frames_to_read * channels;
        let mut actual_samples_read = 0;

        // Pull exactly the needed amount from the iterator
        for i in 0..samples_to_read {
            if let Some(s) = decoder.next() {
                indata[i] = s;
                actual_samples_read += 1;
            } else {
                break;
            }
        }

        let actual_frames_read = actual_samples_read / channels;
        if actual_frames_read == 0 {
            break; // EOF
        }

        if actual_frames_read < frames_to_read {
            indata[actual_samples_read..samples_to_read].fill(0.0);
        }

        let input_adapter = InterleavedSlice::new(&indata, channels, frames_to_read)
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let mut output_adapter = InterleavedSlice::new_mut(&mut outdata, channels, outdata_capacity)
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let (_, frames_written) = resampler
            .process_into_buffer(&input_adapter, &mut output_adapter, Some(&indexing))
            .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;

        let valid_out_samples = frames_written * channels;
        if valid_out_samples > 0 {
            writer
                .write_all(bytemuck::cast_slice(&outdata[..valid_out_samples]))
                .map_err(|e| AudioResamplingError { err_source: e.to_string() })?;
            
            total_written_samples += valid_out_samples as u32;
        }

        if actual_frames_read < frames_to_read {
            break;
        }
    }

    Ok(total_written_samples)
}