use std::io::Write;

use dasp::slice;
use num_traits::ToPrimitive;
use rubato::{
    Fft, FixedSync, Indexing, Resampler,
    audioadapter_buffers::direct::{InterleavedSlice, SequentialSlice},
};

use crate::error::AudioResamplingError;

const CHUNK_SIZE: usize = 8192;

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
            (clamped * 127.0).to_i8().unwrap_or(0)
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
        if let Ok(level) = u32::try_from(samples_per_bin) {
            mipmaps.insert(level, quantized);
        }
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
//
// Uses Rubato's synchronous `Fft` resampler instead of the asynchronous
// Sinc interpolator. Because the input/output sample rates here are always
// fixed, known integers (not a drifting real-time ratio), the FFT resampler
// is the more accurate choice: it works with the exact rational ratio
// between the two sample rates (rather than an f64 approximation of it),
// and applies a brick-wall-accurate antialiasing filter with no
// interpolation error and no tunable quality knobs to get wrong.

/// Resample a non-interleaved buffer using Rubato's high-accuracy FFT resampler.
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

    // `FixedSync::Both` is the recommended mode for resampling an entire
    // in-memory clip in one call: both sides are rounded to fit the exact
    // sample-rate ratio, avoiding internal buffering.
    let mut resampler = Fft::<f32>::new(
        source_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        target_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        CHUNK_SIZE,
        channels,
        FixedSync::Both,
    )
    .map_err(|e| AudioResamplingError {
        err_source: e.to_string(),
    })?;

    let total_in_frames = buffer[0].len();

    // Pack the per-channel slices into one flat Sequential buffer (LLLL... RRRR...)
    let mut indata = vec![0.0f32; channels * total_in_frames];
    for (ch, channel_data) in buffer.iter().enumerate() {
        let start_idx = ch * total_in_frames;
        indata[start_idx..start_idx + total_in_frames].copy_from_slice(channel_data);
    }
    let input_adapter = SequentialSlice::new(&indata, channels, total_in_frames).map_err(|e| {
        AudioResamplingError {
            err_source: e.to_string(),
        }
    })?;

    // Size the output buffer for the worst case, then trim to what was actually produced.
    let needed_out_frames = resampler.process_all_needed_output_len(total_in_frames);
    let mut outdata = vec![0.0f32; channels * needed_out_frames];
    let mut output_adapter = SequentialSlice::new_mut(&mut outdata, channels, needed_out_frames)
        .map_err(|e| AudioResamplingError {
            err_source: e.to_string(),
        })?;

    // `process_all_into_buffer` handles all internal chunking and trims the
    // resampler's startup delay automatically, so the output lines up exactly
    // with the input (unlike a manual chunk loop with a naive length estimate).
    let (_consumed, produced) = resampler
        .process_all_into_buffer(&input_adapter, &mut output_adapter, total_in_frames, None)
        .map_err(|e| AudioResamplingError {
            err_source: e.to_string(),
        })?;

    let mut out: Vec<Vec<f32>> = Vec::with_capacity(channels);
    for ch in 0..channels {
        let start_idx = ch * needed_out_frames;
        out.push(outdata[start_idx..start_idx + produced].to_vec());
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

    let mut resampler = Fft::<f32>::new(
        source_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        target_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        CHUNK_SIZE,
        channels,
        FixedSync::Both,
    )
    .map_err(|e| AudioResamplingError {
        err_source: e.to_string(),
    })?;

    let total_in_frames = buffer.len() / channels;
    let input_adapter = InterleavedSlice::new(buffer, channels, total_in_frames).map_err(|e| {
        AudioResamplingError {
            err_source: e.to_string(),
        }
    })?;

    let needed_out_frames = resampler.process_all_needed_output_len(total_in_frames);
    let mut outdata = vec![0.0f32; channels * needed_out_frames];
    let mut output_adapter = InterleavedSlice::new_mut(&mut outdata, channels, needed_out_frames)
        .map_err(|e| AudioResamplingError {
        err_source: e.to_string(),
    })?;

    let (_consumed, produced) = resampler
        .process_all_into_buffer(&input_adapter, &mut output_adapter, total_in_frames, None)
        .map_err(|e| AudioResamplingError {
            err_source: e.to_string(),
        })?;

    outdata.truncate(produced * channels);
    Ok(outdata)
}

/// Resample an interleaved audio stream directly into a generic writer.
/// Ideal for low-RAM disk streaming or real-time network streams.
///
/// Since the stream's total length isn't known up front, this still processes
/// in a manual chunk loop (unlike the two in-memory functions above), using
/// `FixedSync::Input` so each call consumes exactly `CHUNK_SIZE` input frames.
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
    if source_sample_rate == target_sample_rate {
        let mut total_written_samples: u32 = 0;
        let mut buf = Vec::with_capacity(channels * CHUNK_SIZE);
        for s in decoder {
            buf.push(s);
            if buf.len() == buf.capacity() {
                writer
                    .write_all(bytemuck::cast_slice(&buf))
                    .map_err(|e| AudioResamplingError {
                        err_source: e.to_string(),
                    })?;
                let written = u32::try_from(buf.len()).map_err(|error| AudioResamplingError {
                    err_source: error.to_string(),
                })?;
                total_written_samples += written;
                buf.clear();
            }
        }
        if !buf.is_empty() {
            writer
                .write_all(bytemuck::cast_slice(&buf))
                .map_err(|e| AudioResamplingError {
                    err_source: e.to_string(),
                })?;
            let written = u32::try_from(buf.len()).map_err(|error| AudioResamplingError {
                err_source: error.to_string(),
            })?;
            total_written_samples += written;
        }
        return Ok(total_written_samples);
    }

    let mut resampler = Fft::<f32>::new(
        source_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        target_sample_rate
            .try_into()
            .map_err(|e: std::num::TryFromIntError| AudioResamplingError {
                err_source: e.to_string(),
            })?,
        CHUNK_SIZE,
        channels,
        FixedSync::Input,
    )
    .map_err(|e| AudioResamplingError {
        err_source: e.to_string(),
    })?;

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
        let input_adapter =
            InterleavedSlice::new(&indata, channels, frames_to_read).map_err(|e| {
                AudioResamplingError {
                    err_source: e.to_string(),
                }
            })?;
        let mut output_adapter =
            InterleavedSlice::new_mut(&mut outdata, channels, outdata_capacity).map_err(|e| {
                AudioResamplingError {
                    err_source: e.to_string(),
                }
            })?;
        let (_, frames_written) = resampler
            .process_into_buffer(&input_adapter, &mut output_adapter, Some(&indexing))
            .map_err(|e| AudioResamplingError {
                err_source: e.to_string(),
            })?;
        let valid_out_samples = frames_written * channels;
        if valid_out_samples > 0 {
            writer
                .write_all(bytemuck::cast_slice(&outdata[..valid_out_samples]))
                .map_err(|e| AudioResamplingError {
                    err_source: e.to_string(),
                })?;

            let written =
                u32::try_from(valid_out_samples).map_err(|error| AudioResamplingError {
                    err_source: error.to_string(),
                })?;
            total_written_samples += written;
        }
        if actual_frames_read < frames_to_read {
            break;
        }
    }
    Ok(total_written_samples)
}
