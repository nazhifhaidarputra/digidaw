#![allow(
    clippy::as_conversions,
    clippy::arithmetic_side_effects,
    clippy::cast_possible_truncation,
    clippy::cast_precision_loss,
    clippy::indexing_slicing,
    reason = "audio buffer copying and index bounds are verified by layout checks"
)]

pub use karbeat_dsp::delay::DelayType as DigidawDelayType;
use karbeat_dsp::delay::{DelayDsp, DelayType};
use karbeat_macros::{auto_param, karbeat_plugin};
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;

const DEFAULT_SCRATCH_SIZE: usize = 4096;

/// A multi-mode delay audio effect plugin supporting arbitrary channel configurations.
#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct DigidawDelay {
    /// Master output gain multiplier.
    #[param(
        id = "gain",
        name = "Output Gain",
        group = "Master",
        min = 0.0,
        max = 2.0,
        default = 1.0,
        step = 0.01
    )]
    pub gain: f64,

    /// Core delay processor instance with dynamic delay mode support.
    #[nested(prefix = "delay/")]
    pub delay_dsp_instance: DelayDsp<DelayType>,

    channels: usize,
    sample_rate: f32,
    scratch_buffers: Vec<Vec<f64>>,
}

impl Default for DigidawDelay {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.channels = 2;
        inst.sample_rate = 44100.0;
        inst.scratch_buffers = vec![vec![0.0; DEFAULT_SCRATCH_SIZE]; 8];
        inst
    }
}

impl DigidawDelay {
    /// Returns the currently active delay mode.
    pub fn delay_type(&self) -> DelayType {
        self.delay_dsp_instance.delay_type.get()
    }

    /// Sets the base delay mode (Feedback, PingPong, MultiTap, Off).
    pub fn set_delay_type(&mut self, mode: DelayType) {
        self.delay_dsp_instance.delay_type.set_base(mode);
    }
}

#[auto_param]
impl AudioPlugin for DigidawDelay {
    fn name(&self) -> &str {
        "DigiDAW Delay"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        self.delay_dsp_instance
            .prepare(sample_rate as u32, self.channels);

        let scratch_capacity = max_buffer_size.max(DEFAULT_SCRATCH_SIZE);
        let num_channels = self.channels.max(8);
        self.scratch_buffers = vec![vec![0.0; scratch_capacity]; num_channels];
    }

    fn reset(&mut self) {
        self.delay_dsp_instance.reset();
        for buf in &mut self.scratch_buffers {
            buf.fill(0.0);
        }
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], _outputs: &[BusConfig]) {
        let new_channels = inputs.first().map(|b| b.channel_count).unwrap_or(2);
        if self.channels != new_channels {
            self.channels = new_channels;
            self.delay_dsp_instance
                .prepare(self.sample_rate as u32, self.channels);
            if self.scratch_buffers.len() < self.channels {
                let capacity = self
                    .scratch_buffers
                    .first()
                    .map_or(DEFAULT_SCRATCH_SIZE, Vec::len);
                self.scratch_buffers
                    .resize(self.channels, vec![0.0; capacity]);
            }
        }
    }

    fn tail_samples(&self) -> u32 {
        ((self.delay_dsp_instance.delay_ms.get() * 0.001 * 8.0 * self.sample_rate as f64)
            .clamp(0.0, 10.0 * self.sample_rate as f64)) as u32
    }

    fn process(&mut self, buffers: &mut AudioBuffers, _context: &ProcessContext) {
        if buffers.main_inputs.is_empty() || buffers.main_outputs.is_empty() {
            return;
        }

        let input_bus = &buffers.main_inputs[0];
        let output_bus = &mut buffers.main_outputs[0];

        if input_bus.channel_data.is_empty() || output_bus.channel_data.is_empty() {
            return;
        }

        let total_frames = output_bus.channel_data[0].len();
        if total_frames == 0 {
            return;
        }

        let channels = self
            .channels
            .min(input_bus.channel_data.len())
            .min(output_bus.channel_data.len())
            .min(self.scratch_buffers.len())
            .min(8);

        if channels == 0 {
            return;
        }

        let gain = self.gain.get();
        let chunk_size = self
            .scratch_buffers
            .first()
            .map_or(DEFAULT_SCRATCH_SIZE, Vec::len)
            .max(1);

        let mut frame_offset = 0;
        while frame_offset < total_frames {
            let frames_this_chunk = (total_frames - frame_offset).min(chunk_size);

            for ch in 0..channels {
                let src =
                    &input_bus.channel_data[ch][frame_offset..frame_offset + frames_this_chunk];
                let dst = &mut self.scratch_buffers[ch][..frames_this_chunk];
                for (s, d) in src.iter().zip(dst.iter_mut()) {
                    *d = *s as f64;
                }
            }

            let mut slices_arr: [&mut [f64]; 8] = [
                &mut [],
                &mut [],
                &mut [],
                &mut [],
                &mut [],
                &mut [],
                &mut [],
                &mut [],
            ];

            let (active_scratch, _) = self.scratch_buffers.split_at_mut(channels);
            for (slot, ch_vec) in slices_arr[..channels]
                .iter_mut()
                .zip(active_scratch.iter_mut())
            {
                *slot = &mut ch_vec[..frames_this_chunk];
            }

            self.delay_dsp_instance
                .process_block(&mut slices_arr[..channels]);

            for ch in 0..channels {
                let src = &self.scratch_buffers[ch][..frames_this_chunk];
                let dst = &mut output_bus.channel_data[ch]
                    [frame_offset..frame_offset + frames_this_chunk];
                for (s, d) in src.iter().zip(dst.iter_mut()) {
                    *d = (*s * gain) as f32;
                }
            }

            frame_offset += frames_this_chunk;
        }
    }
}

impl AudioPluginBuilder for DigidawDelay {
    fn build() -> Self {
        Self::default()
    }
}

impl Manifestable for DigidawDelay {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: hash_str("effect_delay"),
            id_string: "effect_delay".to_string(),
            name: "DigiDAW Delay".to_string(),
            internal_type: "DigidawDelay".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn test_process_context() -> ProcessContext<'static> {
        ProcessContext {
            bpm: 120.0,
            time_sig_numerator: 4,
            time_sig_denominator: 4,
            is_playing: true,
            is_recording: false,
            mode: ProcessingMode::Realtime,
            project_time_seconds: 0.0,
            project_time_samples: 0,
            beat_position: 0.0,
            bar_position: 0.0,
            loop_start_beat: None,
            loop_end_beat: None,
            midi_events: &[],
            param_changes: &[],
        }
    }

    #[test]
    fn delay_plugin_exposes_parameters_and_processes_audio() {
        let mut plugin = DigidawDelay::default();
        plugin.prepare(1000.0, 128);

        let specs = plugin.get_parameter_specs();
        let param_paths: Vec<_> = specs.iter().map(|s| s.path.as_str()).collect();

        assert!(param_paths.contains(&"gain"));
        assert!(param_paths.contains(&"delay/delay_ms"));
        assert!(param_paths.contains(&"delay/feedback"));
        assert!(param_paths.contains(&"delay/dry_mix"));
        assert!(param_paths.contains(&"delay/wet_mix"));
        assert!(param_paths.contains(&"delay/type"));

        // Configure delay
        plugin.delay_dsp_instance.delay_ms.set_base(2.0); // 2 samples at 1000 Hz
        plugin.delay_dsp_instance.feedback.set_base(0.5);
        plugin.delay_dsp_instance.dry_mix.set_base(0.0);
        plugin.delay_dsp_instance.wet_mix.set_base(1.0);
        plugin.reset();

        let mut in_l = [1.0f32, 0.0, 0.0, 0.0, 0.0, 0.0];
        let mut in_r = [0.0f32; 6];
        let mut out_l = [0.0f32; 6];
        let mut out_r = [0.0f32; 6];

        let mut in_channels: [&mut [f32]; 2] = [&mut in_l, &mut in_r];
        let mut out_channels: [&mut [f32]; 2] = [&mut out_l, &mut out_r];

        let in_bus = AudioBusBuffer {
            channel_data: &mut in_channels,
            is_silent: false,
        };
        let out_bus = AudioBusBuffer {
            channel_data: &mut out_channels,
            is_silent: false,
        };

        let mut main_inputs = [in_bus];
        let mut main_outputs = [out_bus];

        let mut audio_buffers = AudioBuffers {
            main_inputs: &mut main_inputs,
            main_outputs: &mut main_outputs,
            aux_inputs: &mut [],
            aux_outputs: &mut [],
        };

        let context = test_process_context();

        plugin.process(&mut audio_buffers, &context);

        // Echo should appear at sample 2 on left channel
        assert!((out_l[2] - 1.0).abs() < 1e-4);
        assert!((out_l[4] - 0.5).abs() < 1e-4);
    }
}
