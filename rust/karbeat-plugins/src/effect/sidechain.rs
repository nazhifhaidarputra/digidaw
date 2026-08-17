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
}

impl Default for DigidawSidechainCompressor {
    fn default() -> Self {
        let mut instance = Self::base_default();
        instance.channels = 2;
        instance
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
        let sr_f64 = sample_rate as f64;
        self.compressor_l.prepare(sr_f64);
        self.compressor_r.prepare(sr_f64);
    }

    fn reset(&mut self) {
        self.compressor_l.prepare(48000.0);
        self.compressor_r.prepare(48000.0);
    }

    fn process(&mut self, buffer: &mut AudioBuffers, _context: &ProcessContext) {
        self.compressor_r
            .attack_ms
            .apply_automation(self.compressor_l.attack_ms.get());
        self.compressor_r
            .release_ms
            .apply_automation(self.compressor_l.release_ms.get());
        self.compressor_r
            .ratio
            .apply_automation(self.compressor_l.ratio.get());
        self.compressor_r
            .threshold
            .apply_automation(self.compressor_l.threshold.get());
        self.compressor_r
            .delay_ms
            .apply_automation(self.compressor_l.delay_ms.get());
        self.compressor_r
            .knee
            .apply_automation(self.compressor_l.knee.get());
        self.compressor_r
            .makeup_gain_db
            .apply_automation(self.compressor_l.makeup_gain_db.get());
        self.compressor_r
            .wet_mix
            .apply_automation(self.compressor_l.wet_mix.get());
        self.compressor_r
            .dry_mix
            .apply_automation(self.compressor_l.dry_mix.get());

        if buffer.main_outputs.is_empty() {
            return;
        }

        let main_bus = &mut buffer.main_outputs[0];
        let aux_bus = buffer.aux_inputs.first(); // Optional sidechain bus
        let num_frames = main_bus.channel_data.len();
        let mode = self.mode.get();

        for frame in 0..num_frames {
            let main_l = main_bus.channel_data.get(0).map_or(0.0, |ch| ch[frame]);
            let main_r = main_bus.channel_data.get(1).map_or(0.0, |ch| ch[frame]);

            let sc_l = aux_bus
                .and_then(|b| b.channel_data.get(0))
                .map_or(0.0, |ch| ch[frame]);
            let sc_r = aux_bus
                .and_then(|b| b.channel_data.get(1))
                .map_or(0.0, |ch| ch[frame]);

            match mode {
                StandardChannelMode::Mono => {
                    let out = self.compressor_l.process_sample(main_l, sc_l);

                    if let Some(ch) = main_bus.channel_data.get_mut(0) {
                        ch[frame] = out;
                    }

                    if let Some(ch) = main_bus.channel_data.get_mut(1) {
                        ch[frame] = out;
                    }
                }
                StandardChannelMode::Stereo => {
                    // We feed the exact same sidechain detector signal into BOTH compressors.
                    // The loudest signal between L and R determines the compression amount for both.
                    let sc_linked = if sc_l.abs() > sc_r.abs() { sc_l } else { sc_r };

                    let out_l = self.compressor_l.process_sample(main_l, sc_linked);
                    let out_r = self.compressor_r.process_sample(main_r, sc_linked);

                    if let Some(ch) = main_bus.channel_data.get_mut(0) {
                        ch[frame] = out_l;
                    }

                    if let Some(ch) = main_bus.channel_data.get_mut(1) {
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
