use karbeat_dsp::{channel::StandardChannelMode, compressor::SidechainCompressor};
use karbeat_macros::karbeat_plugin;
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;

/// An audio FX to do sidechain compressing,
/// Meaning that the compression is influenced
/// by another input signal
#[derive(Clone)]
#[karbeat_plugin]
pub struct DigidawSidechainCompressor {
    #[param(id = "channel_mode", name = "Channel Mode", default = StandardChannelMode::Stereo)]
    pub mode: StandardChannelMode,

    // The Left/Main compressor. This one exposes its parameters to the UI via #[nested].
    #[nested(prefix = "compressor/")]
    pub compressor_l: SidechainCompressor,

    // The Right compressor. Acts purely as internal DSP state.
    // It is NOT exposed to the UI; we will sync its parameters from compressor_l manually.
    pub compressor_r: SidechainCompressor,

    // Tracks the current channel layout
    channels: usize,

    // Used to report lookahead latency to the host's PDC system.
    sample_rate: f32,
    reported_latency_samples: u32,
}

impl Default for DigidawSidechainCompressor {
    fn default() -> Self {
        let mut instance = Self::base_default();
        instance.channels = 2;
        instance.sample_rate = 48_000.0;
        instance.reported_latency_samples = 0;
        instance
    }
}

impl DigidawSidechainCompressor {
    fn current_latency_samples(&self) -> u32 {
        ((self.compressor_l.delay_ms.get().max(0) as f32 * 0.001 * self.sample_rate).round()) as u32
    }
}

#[karbeat_macros::auto_param]
impl AudioPlugin for DigidawSidechainCompressor {
    fn name(&self) -> &str {
        "DigiDAW Sidechain Compressor"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
        let sr_f64 = sample_rate as f64;
        self.compressor_l.prepare(sr_f64);
        self.compressor_r.prepare(sr_f64);
        self.reported_latency_samples = self.current_latency_samples();
    }

    fn reset(&mut self) {
        let sample_rate = self.sample_rate as f64;
        self.compressor_l.prepare(sample_rate);
        self.compressor_r.prepare(sample_rate);
    }

    fn process(&mut self, buffer: &mut AudioBuffers, _context: &ProcessContext) {
        self.compressor_r
            .attack_ms
            .set_base(self.compressor_l.attack_ms.get());
        self.compressor_r
            .release_ms
            .set_base(self.compressor_l.release_ms.get());
        self.compressor_r
            .ratio
            .set_base(self.compressor_l.ratio.get());
        self.compressor_r
            .threshold
            .set_base(self.compressor_l.threshold.get());
        self.compressor_r
            .delay_ms
            .set_base(self.compressor_l.delay_ms.get());
        self.compressor_r
            .knee
            .set_base(self.compressor_l.knee.get());
        self.compressor_r
            .makeup_gain_db
            .set_base(self.compressor_l.makeup_gain_db.get());
        self.compressor_r
            .wet_mix
            .set_base(self.compressor_l.wet_mix.get());
        self.compressor_r
            .dry_mix
            .set_base(self.compressor_l.dry_mix.get());

        if buffer.main_inputs.is_empty() || buffer.main_outputs.is_empty() {
            return;
        }

        let main_inputs = &buffer.main_inputs[0].channel_data;
        let main_outputs = &mut buffer.main_outputs[0].channel_data;
        let aux_bus = buffer.aux_inputs.first(); // Optional sidechain bus
        let num_frames = main_inputs
            .first()
            .map_or(0, |channel| channel.len())
            .min(main_outputs.first().map_or(0, |channel| channel.len()));
        let mode = self.mode.get();

        for frame in 0..num_frames {
            let main_l = main_inputs.first().map_or(0.0, |ch| ch[frame]);
            let main_r = main_inputs.get(1).map_or(main_l, |ch| ch[frame]);

            let sc_l = aux_bus
                .and_then(|b| b.channel_data.get(0))
                .and_then(|ch| ch.get(frame))
                .copied()
                .unwrap_or(0.0);
            let sc_r = aux_bus
                .and_then(|b| b.channel_data.get(1))
                .and_then(|ch| ch.get(frame))
                .copied()
                .unwrap_or(sc_l);

            match mode {
                StandardChannelMode::Mono => {
                    let out = self.compressor_l.process_sample(main_l, sc_l);

                    if let Some(ch) = main_outputs.get_mut(0) {
                        ch[frame] = out;
                    }

                    if let Some(ch) = main_outputs.get_mut(1) {
                        ch[frame] = out;
                    }
                }
                StandardChannelMode::Stereo => {
                    // We feed the exact same sidechain detector signal into BOTH compressors.
                    // The loudest signal between L and R determines the compression amount for both.
                    let sc_linked = if sc_l.abs() > sc_r.abs() { sc_l } else { sc_r };

                    let out_l = self.compressor_l.process_sample(main_l, sc_linked);
                    let out_r = self.compressor_r.process_sample(main_r, sc_linked);

                    if let Some(ch) = main_outputs.get_mut(0) {
                        ch[frame] = out_l;
                    }

                    if let Some(ch) = main_outputs.get_mut(1) {
                        ch[frame] = out_r;
                    }
                }
            }
        }
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], _outputs: &[BusConfig]) {
        let new_channels = inputs.first().map(|b| b.channel_count).unwrap_or(2);
        if self.channels != new_channels {
            self.channels = new_channels;
        }
    }

    fn latency_samples(&self) -> u32 {
        self.current_latency_samples()
    }

    fn has_latency_changed(&mut self) -> bool {
        let current = self.current_latency_samples();
        let changed = current != self.reported_latency_samples;
        self.reported_latency_samples = current;
        changed
    }
}

impl AudioPluginBuilder for DigidawSidechainCompressor {
    fn build() -> Self {
        Self::default()
    }
}

impl Manifestable for DigidawSidechainCompressor {
    fn build_manifest() -> PluginManifest {
        let id_str = "effect_digidaw_sidechain_comp";
        PluginManifest {
            id: hash_str(id_str),
            id_string: id_str.to_owned(),
            name: "DigiDAW Sidechain Compressor".to_string(),
            internal_type: "DigidawSidechainCompressor".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_plugin_api::types::{AudioBusBuffer, ProcessingMode};

    fn process_context() -> ProcessContext<'static> {
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

    fn parameter_id(plugin: &DigidawSidechainCompressor, path: &str) -> u32 {
        plugin
            .get_parameter_specs()
            .into_iter()
            .find(|spec| spec.path == path)
            .unwrap_or_else(|| panic!("missing parameter {path}"))
            .id
    }

    fn process_stereo(
        plugin: &mut DigidawSidechainCompressor,
        left: &[f32],
        right: &[f32],
        sidechain_left: Option<&mut [f32]>,
        sidechain_right: Option<&mut [f32]>,
    ) -> (Vec<f32>, Vec<f32>) {
        let mut input_left = left.to_vec();
        let mut input_right = right.to_vec();
        let mut output_left = vec![0.0; left.len()];
        let mut output_right = vec![0.0; right.len()];
        let mut aux_outputs = [];

        {
            let mut input_channels: [&mut [f32]; 2] = [&mut input_left, &mut input_right];
            let input_bus = AudioBusBuffer {
                channel_data: &mut input_channels,
                is_silent: false,
            };
            let mut main_inputs = [input_bus];
            let mut output_channels: [&mut [f32]; 2] = [&mut output_left, &mut output_right];
            let output_bus = AudioBusBuffer {
                channel_data: &mut output_channels,
                is_silent: false,
            };
            let mut main_outputs = [output_bus];

            match (sidechain_left, sidechain_right) {
                (Some(sc_left), Some(sc_right)) => {
                    let mut aux_channels: [&mut [f32]; 2] = [sc_left, sc_right];
                    let aux_bus = AudioBusBuffer {
                        channel_data: &mut aux_channels,
                        is_silent: false,
                    };
                    let mut aux_inputs = [aux_bus];
                    let mut buffers = AudioBuffers {
                        main_inputs: &mut main_inputs,
                        main_outputs: &mut main_outputs,
                        aux_inputs: &mut aux_inputs,
                        aux_outputs: &mut aux_outputs,
                    };
                    plugin.process(&mut buffers, &process_context());
                }
                _ => {
                    let mut aux_inputs = [];
                    let mut buffers = AudioBuffers {
                        main_inputs: &mut main_inputs,
                        main_outputs: &mut main_outputs,
                        aux_inputs: &mut aux_inputs,
                        aux_outputs: &mut aux_outputs,
                    };
                    plugin.process(&mut buffers, &process_context());
                }
            }
        }

        (output_left, output_right)
    }

    #[test]
    fn processes_the_entire_audio_block_without_a_sidechain() {
        let mut plugin = DigidawSidechainCompressor::default();
        plugin.prepare(48_000.0, 64);
        let input_left = vec![0.25; 32];
        let input_right = vec![-0.25; 32];

        let (left, right) = process_stereo(&mut plugin, &input_left, &input_right, None, None);

        assert!(left.iter().all(|sample| (*sample - 0.25).abs() < 1.0e-6));
        assert!(right.iter().all(|sample| (*sample + 0.25).abs() < 1.0e-6));
    }

    #[test]
    fn default_settings_duck_both_stereo_channels_when_sidechain_is_present() {
        let mut plugin = DigidawSidechainCompressor::default();
        plugin.prepare(48_000.0, 4096);
        plugin.set_parameter(parameter_id(&plugin, "compressor/attack"), 1.0);

        let input_left = vec![0.5; 4096];
        let input_right = vec![0.25; 4096];
        let mut sc_left = vec![1.0; 4096];
        let mut sc_right = vec![0.0; 4096];

        let (left, right) = process_stereo(
            &mut plugin,
            &input_left,
            &input_right,
            Some(&mut sc_left),
            Some(&mut sc_right),
        );

        assert!(left[4095].abs() < 0.2);
        assert!(right[4095].abs() < 0.1);
    }

    #[test]
    fn reports_lookahead_latency_changes() {
        let mut plugin = DigidawSidechainCompressor::default();
        plugin.prepare(48_000.0, 64);
        assert_eq!(plugin.latency_samples(), 0);
        assert!(!plugin.has_latency_changed());

        plugin.set_parameter(parameter_id(&plugin, "compressor/delay"), 10.0);

        assert_eq!(plugin.latency_samples(), 480);
        assert!(plugin.has_latency_changed());
        assert!(!plugin.has_latency_changed());
    }

    #[test]
    fn channel_mode_metadata_uses_choice_indices() {
        let plugin = DigidawSidechainCompressor::default();
        let spec = plugin
            .get_parameter_specs()
            .into_iter()
            .find(|spec| spec.path == "channel_mode")
            .expect("channel mode parameter");

        assert_eq!(spec.default_value, 1.0);
        assert_eq!(spec.min, 0.0);
        assert_eq!(spec.max, 1.0);
    }
}
