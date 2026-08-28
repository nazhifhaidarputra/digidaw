use dasp::slice;
use hashbrown::HashMap;
use itertools::{Itertools, izip};
use karbeat_plugin_api::types::{AudioBuffers, AudioBusBuffer, ProcessContext};
use karbeat_plugin_types::{Param, SmoothableParam};
use karbeat_utils::math::hermite_interp;
use rodio::math::db_to_linear;
use wide::f32x16;

use crate::{
    commands::MixerChannelTarget,
    core::project::{
        AutomationTarget, MixerChannelParamTarget, MixerChannelParams, RoutingConnection,
        RoutingNode, TrackAutomationTarget, audio_waveform::AudioSampleMode,
    },
    shared::{BusId, TrackId},
};

/// Unified entry point to render an audio waveform slice.
/// Safely delegates to the correct DSP algorithm based on the chosen sample mode.
#[inline(always)]
#[allow(clippy::too_many_arguments)]
pub fn render_audio_waveform(
    mode: &AudioSampleMode,
    source_buffer: &[f32],
    src_channels: usize,
    target_slice: &mut [f32],
    target_channels: usize,
    source_read_index: &mut f64,
    step: f64,
    is_looping: bool,
    loop_len: f64,
    base_volume: f32,
    current_elapsed_samples: Option<&mut u32>,
    fade_samples: u32,
    clip_loop_length: u32,
) {
    match mode {
        // For default and resampled mode, we use pointer
        // calculation and hermite interpolation
        // to read the scratch buffer
        AudioSampleMode::Default | AudioSampleMode::Resampled => {
            let mut frames_written = 0;
            let trim_end = loop_len;
            let start_bound = 0.0;

            let start_elapsed = current_elapsed_samples.as_ref().map(|v| **v).unwrap_or(0);

            if target_channels == 2 {
                let (simd_chunks, remaining_samples) = target_slice.as_chunks_mut::<16>();

                for chunk in simd_chunks {
                    let mut s = [0.0; 16];
                    let mut f = [0.0; 16];

                    // Let LLVM pipeline the scalar interpolations
                    for i in 0..8 {
                        let elapsed = start_elapsed + frames_written + i;
                        let rp = get_read_pos(
                            *source_read_index,
                            ((frames_written + i) as f64) * step,
                            is_looping,
                            trim_end,
                            start_bound,
                            loop_len,
                        );

                        let s_frame = sample_waveform_dasp(source_buffer, rp, src_channels);
                        let fade = if current_elapsed_samples.is_some() {
                            calc_fade(elapsed, fade_samples, clip_loop_length)
                        } else {
                            1.0
                        } * base_volume;

                        s[i as usize * 2] = s_frame[0];
                        s[i as usize * 2 + 1] = s_frame[1];
                        f[i as usize * 2] = fade;
                        f[i as usize * 2 + 1] = fade;
                    }

                    let samples = f32x16::new(s);
                    let fades = f32x16::new(f);
                    let mut out_v = f32x16::new(*chunk);

                    out_v += samples * fades;
                    *chunk = out_v.to_array();

                    frames_written += 8;
                }

                for (left, right) in remaining_samples.iter_mut().tuples::<(_, _)>() {
                    let elapsed0 = start_elapsed + frames_written;
                    let rp0 = get_read_pos(
                        *source_read_index,
                        (frames_written as f64) * step,
                        is_looping,
                        trim_end,
                        start_bound,
                        loop_len,
                    );
                    let s0 = sample_waveform_dasp(source_buffer, rp0, src_channels);
                    let fade0 = if current_elapsed_samples.is_some() {
                        calc_fade(elapsed0, fade_samples, clip_loop_length)
                    } else {
                        1.0
                    } * base_volume;

                    *left += s0[0] * fade0;
                    *right += s0[1] * fade0;
                    frames_written += 1;
                }
            } else {
                // Non-stereo fallback processing 16 mono frames at a time
                let (simd_chunks, remaining_samples) = target_slice.as_chunks_mut::<16>();
                for chunk in simd_chunks {
                    let mut s = [0.0; 16];
                    let mut f = [0.0; 16];

                    for i in 0..16 {
                        let elapsed = start_elapsed + frames_written + i;
                        let rp = get_read_pos(
                            *source_read_index,
                            ((frames_written + i) as f64) * step,
                            is_looping,
                            trim_end,
                            start_bound,
                            loop_len,
                        );

                        s[i as usize] = sample_waveform_dasp(source_buffer, rp, src_channels)[0];
                        f[i as usize] = if current_elapsed_samples.is_some() {
                            calc_fade(elapsed, fade_samples, clip_loop_length)
                        } else {
                            1.0
                        } * base_volume;
                    }

                    let samples = f32x16::new(s);
                    let fades = f32x16::new(f);
                    let mut out_v = f32x16::new(*chunk);

                    out_v += samples * fades;
                    *chunk = out_v.to_array();

                    frames_written += 16;
                }

                for sample in remaining_samples {
                    let elapsed = start_elapsed + frames_written;
                    let rp = get_read_pos(
                        *source_read_index,
                        (frames_written as f64) * step,
                        is_looping,
                        trim_end,
                        start_bound,
                        loop_len,
                    );

                    let s0 = sample_waveform_dasp(source_buffer, rp, src_channels);
                    let fade0 = if current_elapsed_samples.is_some() {
                        calc_fade(elapsed, fade_samples, clip_loop_length)
                    } else {
                        1.0
                    } * base_volume;

                    *sample += s0[0] * fade0;
                    frames_written += 1;
                }
            }

            // Advance the read pointer safely
            *source_read_index = get_read_pos(
                *source_read_index,
                (frames_written as f64) * step,
                is_looping,
                trim_end,
                start_bound,
                loop_len,
            );
            if let Some(elapsed) = current_elapsed_samples {
                *elapsed += frames_written;
            }
        }
        AudioSampleMode::Stretch => {
            // TODO: Implement WSOLA or Granular Engine logic
        }
    }
}

/// Sample a waveform at a specific position using dasp interpolation.
/// Handles fallback from 1-channel to 2-channel stereo.
#[inline]
pub fn sample_waveform_dasp(buffer: &[f32], pos: f64, src_channels: usize) -> [f32; 2] {
    let idx = pos as usize;
    let alpha = (pos - (idx as f64)) as f32;

    if src_channels == 2 {
        let frames: &[[f32; 2]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let len = frames.len();

        if idx >= len {
            return [0.0, 0.0];
        }

        if alpha == 0.0 {
            return frames[idx];
        }

        let p0 = if idx > 0 {
            frames[idx - 1]
        } else {
            frames[idx]
        };
        let p1 = frames[idx];
        let p2 = if idx + 1 < len { frames[idx + 1] } else { p1 };
        let p3 = if idx + 2 < len { frames[idx + 2] } else { p2 };

        [
            hermite_interp(alpha, p0[0], p1[0], p2[0], p3[0]),
            hermite_interp(alpha, p0[1], p1[1], p2[1], p3[1]),
        ]
    } else {
        let frames: &[[f32; 1]] = slice::from_sample_slice(buffer).unwrap_or(&[]);
        let len = frames.len();

        if idx >= len {
            return [0.0, 0.0];
        }

        if alpha == 0.0 {
            let val = frames[idx][0];
            return [val, val];
        }

        let p0 = if idx > 0 {
            frames[idx - 1]
        } else {
            frames[idx]
        };
        let p1 = frames[idx];
        let p2 = if idx + 1 < len { frames[idx + 1] } else { p1 };
        let p3 = if idx + 2 < len { frames[idx + 2] } else { p2 };

        let val = hermite_interp(alpha, p0[0], p1[0], p2[0], p3[0]);
        [val, val]
    }
}
#[inline(always)]
pub fn calc_fade(current_elapsed: u32, fade_samples: u32, loop_length: u32) -> f32 {
    if fade_samples == 0 {
        return 1.0;
    }
    if current_elapsed < fade_samples {
        (current_elapsed as f32) / (fade_samples as f32)
    } else if current_elapsed + fade_samples > loop_length {
        let remaining = loop_length.saturating_sub(current_elapsed);
        (remaining as f32) / (fade_samples as f32)
    } else {
        1.0
    }
}

#[inline(always)]
pub fn get_read_pos(
    base_idx: f64,
    offset: f64,
    is_looping: bool,
    trim_end: f64,
    start_bound: f64,
    loop_len: f64,
) -> f64 {
    let rp = base_idx + offset;
    if is_looping && rp >= trim_end {
        start_bound + ((rp - trim_end) % loop_len)
    } else {
        rp
    }
}

/// Helper function to decode 16-bit PCM WAV bytes into a flat f32 array
pub fn load_internal_wav(bytes: &[u8]) -> Vec<f32> {
    let cursor = std::io::Cursor::new(bytes);
    let Ok(reader) = hound::WavReader::new(cursor) else {
        return Vec::new();
    };

    // Convert 16-bit integer (-32768 to 32767) to f32 (-1.0 to 1.0)
    reader
        .into_samples::<i16>()
        .map(|s| (s.unwrap_or(0) as f32) / 32768.0)
        .collect()
}

#[inline(always)]
pub fn apply_phase_inversion_simd(buffer: &mut [f32]) {
    let neg_one = f32x16::splat(-1.0);
    let (simd_chunks, remaining_samples) = buffer.as_chunks_mut::<16>();

    for chunk in simd_chunks {
        let mut v = f32x16::new(*chunk);
        v *= neg_one;
        *chunk = v.to_array();
    }

    for sample in remaining_samples {
        *sample = -*sample;
    }
}

#[inline(always)]
pub fn apply_volume_and_pan_simd(
    buffer: &mut [f32],
    channels: usize,
    vol_param: &mut Param<f32>,
    pan_param: &mut Param<f32>,
) {
    if channels == 2 {
        for (left, right) in buffer.iter_mut().tuples::<(_, _)>() {
            let vol_db = vol_param.next_smoothed();
            let pan = pan_param.next_smoothed();

            // Handle the true silence threshold natively per-sample
            let vol = if vol_db <= -100.0 {
                0.0
            } else {
                db_to_linear(vol_db as f32)
            };

            let p = (pan as f32 + 1.0) * 0.5;
            let left_gain = (1.0 - p).sqrt() * vol;
            let right_gain = p.sqrt() * vol;

            *left *= left_gain;
            *right *= right_gain;
        }
    } else {
        // Mono fallback
        let frames = buffer.len() / channels;
        for sample in buffer.iter_mut().step_by(channels).take(frames) {
            let vol_db = vol_param.next_smoothed();
            let vol = if vol_db <= -100.0 {
                0.0
            } else {
                db_to_linear(vol_db as f32)
            };
            *sample *= vol;
        }
    }
}

#[inline(always)]
pub fn process_plugin_wrapper(
    plugin: &mut dyn crate::core::project::plugin::AudioPlugin,
    interleaved_io: &mut [f32],
    aux_interleaved: Option<&[f32]>,
    channels: usize,
    ctx: &ProcessContext,
    channel_buffers_in: &mut [Vec<f32>],
    channel_buffers_out: &mut [Vec<f32>],
    aux_channel_buffers: &mut [Vec<f32>],
) {
    let frames = interleaved_io.len() / channels;

    // Resize all necessary buffers upfront
    channel_buffers_in
        .iter_mut()
        .take(channels)
        .chain(channel_buffers_out.iter_mut().take(channels))
        .for_each(|buffer| {
            if buffer.len() < frames {
                buffer.resize(frames, 0.0);
            }
        });
    if aux_interleaved.is_some() {
        aux_channel_buffers
            .iter_mut()
            .take(channels)
            .for_each(|buffer| {
                if buffer.len() < frames {
                    buffer.resize(frames, 0.0);
                }
            });
    }

    // Deinterleave Main & Aux Buses
    deinterleave_buffer(interleaved_io, channel_buffers_in, channels, frames);
    if let Some(aux) = aux_interleaved {
        deinterleave_buffer(aux, aux_channel_buffers, channels, frames);
    }

    // Setup Pointers for the Plugin API
    let mut in_ptrs: Vec<&mut [f32]> = channel_buffers_in
        .iter_mut()
        .take(channels)
        .map(|v| &mut v[..frames])
        .collect();

    let mut out_ptrs: Vec<&mut [f32]> = channel_buffers_out
        .iter_mut()
        .take(channels)
        .map(|v| &mut v[..frames])
        .collect();

    let mut main_in = [AudioBusBuffer {
        channel_data: &mut in_ptrs,
        is_silent: false,
    }];
    let mut main_out = [AudioBusBuffer {
        channel_data: &mut out_ptrs,
        is_silent: false,
    }];

    let mut aux_in_bus = vec![];
    let mut aux_in_ptrs: Vec<&mut [f32]>;
    if aux_interleaved.is_some() {
        aux_in_ptrs = aux_channel_buffers
            .iter_mut()
            .take(channels)
            .map(|v| &mut v[..frames])
            .collect();
        aux_in_bus.push(AudioBusBuffer {
            channel_data: &mut aux_in_ptrs,
            is_silent: false,
        });
    }

    let mut buffers = AudioBuffers {
        main_inputs: &mut main_in,
        main_outputs: &mut main_out,
        aux_inputs: &mut aux_in_bus,
        aux_outputs: &mut [],
    };

    // Execute Plugin DSP
    plugin.process(&mut buffers, ctx);

    interleave_buffer(interleaved_io, channel_buffers_out, channels, frames);
}

#[inline]
fn deinterleave_buffer(
    interleaved: &[f32],
    channel_buffers: &mut [Vec<f32>],
    channels: usize,
    frames: usize,
) {
    if channels == 2 {
        let (left, right) = channel_buffers.split_at_mut(1);
        izip!(
            left[0][..frames].iter_mut(),
            right[0][..frames].iter_mut(),
            interleaved.iter().copied().tuples::<(_, _)>()
        )
        .for_each(|(left, right, (source_left, source_right))| {
            *left = source_left;
            *right = source_right;
        });
        return;
    }

    for (channel_index, destination) in channel_buffers.iter_mut().take(channels).enumerate() {
        destination[..frames].iter_mut().set_from(
            interleaved
                .iter()
                .skip(channel_index)
                .step_by(channels)
                .copied(),
        );
    }
}

#[inline]
fn interleave_buffer(
    interleaved: &mut [f32],
    channel_buffers: &[Vec<f32>],
    channels: usize,
    frames: usize,
) {
    if channels == 2 {
        interleaved.iter_mut().set_from(
            channel_buffers[0][..frames]
                .iter()
                .copied()
                .interleave(channel_buffers[1][..frames].iter().copied()),
        );
        return;
    }

    for (channel_index, source) in channel_buffers.iter().take(channels).enumerate() {
        interleaved
            .iter_mut()
            .skip(channel_index)
            .step_by(channels)
            .set_from(source[..frames].iter().copied());
    }
}

// =============================================================================
// Routing Order Helper
// =============================================================================

/// Compute a topologically sorted routing order (sources → buses → master)
/// from plain routing data and known track/bus IDs.
///
/// This replicates MixerState::get_routing_order without needing the full
/// MixerState on the audio thread.
pub fn compute_routing_order(
    track_ids: impl Iterator<Item = TrackId>,
    bus_ids: impl Iterator<Item = BusId>,
    routing: &[RoutingConnection],
) -> Vec<RoutingNode> {

    let bus_ids_vec: Vec<BusId> = bus_ids.collect();

    // All tracks come first
    let mut order: Vec<RoutingNode> = track_ids.map(RoutingNode::Track).collect();

    // Kahn's topological sort for buses
    let mut in_degree: HashMap<BusId, usize> = bus_ids_vec.iter().map(|&id| (id, 0)).collect();
    let mut adj: HashMap<BusId, Vec<BusId>> = bus_ids_vec.iter().map(|&id| (id, vec![])).collect();

    for conn in routing {
        if let (RoutingNode::Bus(src), RoutingNode::Bus(dst)) = (conn.source, conn.destination) {
            if let Some(neighbors) = adj.get_mut(&src) {
                neighbors.push(dst);
            }
            if let Some(deg) = in_degree.get_mut(&dst) {
                *deg += 1;
            }
        }
    }

    let mut queue: std::collections::VecDeque<BusId> = in_degree
        .iter()
        .filter(|(_, deg)| **deg == 0)
        .map(|(&id, _)| id)
        .collect();

    while let Some(bus_id) = queue.pop_front() {
        order.push(RoutingNode::Bus(bus_id));
        if let Some(neighbors) = adj.get(&bus_id) {
            for &neighbor in neighbors {
                if let Some(deg) = in_degree.get_mut(&neighbor) {
                    *deg -= 1;
                    if *deg == 0 {
                        queue.push_back(neighbor);
                    }
                }
            }
        }
    }

    order.push(RoutingNode::Master);
    order
}

pub fn resolve_target_mixer_param(
    target: &MixerChannelTarget,
    param: &MixerChannelParams,
) -> (Option<AutomationTarget>, f32) {
    // First, extract the generic mixer target and the float value
    let (mix_target, val) = match param {
        MixerChannelParams::Volume(v) => (
            Some(MixerChannelParamTarget::Volume),
            ((*v - (-60.0)) / 66.0).clamp(0.0, 1.0),
        ),
        MixerChannelParams::Pan(v) => (
            Some(MixerChannelParamTarget::Pan),
            ((*v - (-1.0)) / 2.0).clamp(0.0, 1.0),
        ),
        MixerChannelParams::Mute(v) => (None, if *v { 1.0 } else { 0.0 }),
        MixerChannelParams::InvertedPhase(v) => (None, if *v { 1.0 } else { 0.0 }),
        MixerChannelParams::Solo(v) => (None, if *v { 1.0 } else { 0.0 }),
    };

    // If it's an automatable parameter, wrap it in its specific track/bus/master parent
    let automation_target = mix_target.map(|mt| match target {
        MixerChannelTarget::Track(track_id) => AutomationTarget::Track {
            track_id: *track_id,
            track_target: TrackAutomationTarget::MixerChannel(mt),
        },
        MixerChannelTarget::Bus(bus_id) => AutomationTarget::Bus {
            bus_id: *bus_id,
            mix_target: mt,
        },
        MixerChannelTarget::Master => AutomationTarget::Master(
            crate::core::project::MasterAutomationTarget::MixerChannel(mt),
        ),
    });

    (automation_target, val)
}

#[cfg(test)]
mod buffer_iteration_tests {
    use super::{apply_phase_inversion_simd, deinterleave_buffer, interleave_buffer};

    #[test]
    fn stereo_deinterleave_round_trip_leaves_incomplete_frame_untouched() {
        let input = [1.0, 2.0, 3.0, 4.0, 99.0];
        let mut channels = vec![vec![0.0; 2], vec![0.0; 2]];

        deinterleave_buffer(&input, &mut channels, 2, 2);

        assert_eq!(channels, [[1.0, 3.0], [2.0, 4.0]]);

        let mut output = [0.0, 0.0, 0.0, 0.0, 99.0];
        interleave_buffer(&mut output, &channels, 2, 2);

        assert_eq!(output, input);
    }

    #[test]
    fn multichannel_deinterleave_round_trip() {
        let input = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0];
        let mut channels = vec![vec![0.0; 2], vec![0.0; 2], vec![0.0; 2]];

        deinterleave_buffer(&input, &mut channels, 3, 2);

        assert_eq!(channels, [[1.0, 4.0], [2.0, 5.0], [3.0, 6.0]]);

        let mut output = [0.0; 6];
        interleave_buffer(&mut output, &channels, 3, 2);

        assert_eq!(output, input);
    }

    #[test]
    fn phase_inversion_processes_simd_remainder() {
        let mut buffer: Vec<f32> = (1..=19).map(|sample| sample as f32).collect();

        apply_phase_inversion_simd(&mut buffer);

        assert_eq!(
            buffer,
            (1..=19).map(|sample| -(sample as f32)).collect::<Vec<_>>()
        );
    }
}
