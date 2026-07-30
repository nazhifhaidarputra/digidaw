use karbeat_dsp::pitch_shift::{PitchShiftAlgorithm, PitchShiftEngine};
use karbeat_macros::{auto_param, karbeat_plugin};
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;

/// The audio FX Plugin for real-time, low-latency Pitch Shifting.
///
/// Uses Rubberband via FFI bindings under the hood. To be able to run
/// this, you must install rubberband system-wide.
/// For further information, see https://breakfastquay.com/rubberband/
#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct Pitcher {
    #[param(id = "mode", name = "Pitch Shift mode", group = "Pitcher")]
    pub mode: PitchShiftAlgorithm,

    // ==========================
    // Pitch shift algorithm engine
    // ==========================
    #[nested(prefix = "engine/")]
    pub pitch_shift_engine: PitchShiftEngine,

    channels: usize,
    sample_rate: f32,
}

impl Default for Pitcher {
    fn default() -> Self {
        let mut def = Self::base_default();
        def.channels = 2; // Default to stereo
        def.sample_rate = 44100.0;
        def
    }
}

#[auto_param]
impl AudioPlugin for Pitcher {
    fn name(&self) -> &str {
        "Digidaw Pitcher"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn reset(&mut self) {
        self.pitch_shift_engine.reset();
    }

    fn prepare(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        self.pitch_shift_engine.prepare(sample_rate, self.channels);
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], _outputs: &[BusConfig]) {
        let new_channels = inputs.first().map(|b| b.channel_count).unwrap_or(2);

        if self.channels != new_channels {
            self.channels = new_channels;
            // Rebuild the rubberband instance with the new channel count.
            self.pitch_shift_engine
                .prepare(self.sample_rate, self.channels);
        }
    }

    /// Report the latency of the plugin to the audio engine in samples.
    /// Delegates to the rubberband engine which queries the library directly.
    fn latency_samples(&self) -> u32 {
        self.pitch_shift_engine.latency_samples()
    }

    /// Report the tail of the plugin to the audio engine in samples.
    /// Ensures that if the transport stops or the clip ends, the shifter's
    /// internal buffers can drain to silence.
    fn tail_samples(&self) -> u32 {
        self.pitch_shift_engine.latency_samples()
    }

    fn has_latency_changed(&mut self) -> bool {
        false
    }

    fn process(&mut self, buffers: &mut AudioBuffers, _context: &ProcessContext) {
        if buffers.main_inputs.is_empty() || buffers.main_outputs.is_empty() {
            return;
        }

        // Safeguard channels to a max of 8 (7.1 surround) to avoid excessive
        // heap allocation on the audio thread.
        let channels = self.channels.min(8);

        // Copy input into output bus so we can process in-place.
        let num_frames = buffers.main_outputs[0].channel_data[0].len();

        // Build a staging buffer for in-place processing.
        // Stack-allocate up to 8 channels with a fixed-size array of Vecs.
        let input_bus = &buffers.main_inputs[0];

        // We need to copy into output first so we can pass &mut to the engine.
        for ch in 0..channels {
            let src = &input_bus.channel_data[ch];
            let dst = &mut buffers.main_outputs[0].channel_data[ch];
            let n = num_frames.min(src.len()).min(dst.len());
            dst[..n].copy_from_slice(&src[..n]);
        }

        match self.mode.get() {
            PitchShiftAlgorithm::WSOLA => {
                let output_bus = &mut buffers.main_outputs[0];
                let mut slices_arr: [&mut [f32]; 8] = [
                    &mut [],
                    &mut [],
                    &mut [],
                    &mut [],
                    &mut [],
                    &mut [],
                    &mut [],
                    &mut [],
                ];
                for (slot, ch) in slices_arr
                    .iter_mut()
                    .zip(output_bus.channel_data.iter_mut())
                {
                    *slot = &mut **ch;
                }
                self.pitch_shift_engine
                    .process_block(&mut slices_arr[..channels])
            }
        }
    }
}

impl Manifestable for Pitcher {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: hash_str("effect_pitcher"),
            id_string: "effect_pitcher".to_string(),
            name: "Pitcher".to_string(),
            internal_type: "Pitcher".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}

impl AudioPluginBuilder for Pitcher {
    fn build() -> Self {
        Self::default()
    }
}
