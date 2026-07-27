use karbeat_dsp::{
    distortion::DistortionType, envelope::AdvancedEnvelopeSettings, lfo::Lfo, noise::NoiseColor,
};
use karbeat_macros::{karbeat_plugin, EnumParam};
use karbeat_plugin_api::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum SpectralMorphType {
    None,
    Vocode,
    FormantScale,
    HarmonicStretch,
    Inharmonic,
    Smear,
    RandomPhase,
}

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum FilterDestination {
    None,
    Filter1,
    Filter2,
    Both,
}

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum FilterRouting {
    Serial,
    Parallel,
    Split,
}

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum PortamentoMode {
    Off,
    Always,
    Legato,
}

/// Preset for collection of waveform formed by wavetable
pub struct WavetablePreset {}

#[karbeat_plugin]
#[derive(Clone)]
pub struct WavetableOsc {
    #[param(
        id = "wt_pos",
        name = "Wavetable Pos",
        group = "Oscillator",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    wt_pos: f64,

    #[param(id = "on", name = "On", group = "Oscillator", default = true)]
    pub enabled: bool,

    #[param(
        id = "level_db",
        name = "Level",
        group = "Oscillator",
        min = -60.0,
        max = 6.0,
        default = 0.0,
        step = 0.1
    )]
    pub level_db: f64,

    #[param(
        id = "pan",
        name = "Pan",
        group = "Oscillator",
        min = -1.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub pan: f64,

    // ==========================
    // Pitches
    // ==========================
    #[param(
        id = "coarse",
        name = "Coarse Tune",
        group = "Pitch",
        min = -48.0,
        max = 48.0,
        default = 0.0,
        step = 1.0
    )]
    pub coarse_tune: i32,

    #[param(
        id = "fine",
        name = "Fine Tune",
        group = "Pitch",
        min = -100.0,
        max = 100.0,
        default = 0.0,
        step = 0.01
    )]
    pub fine_tune: f64,

    #[param(
        id = "key_track",
        name = "Key Track",
        group = "Pitch",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.001
    )]
    pub key_track: f64,

    // ==========================
    // Pitches
    // ==========================
    #[param(
        id = "unison_voices",
        name = "Unison Voices",
        group = "Unison",
        min = 1.0,
        max = 16.0,
        default = 1.0,
        step = 1.0
    )]
    pub unison_voices: i32,

    #[param(
        id = "unison_detune",
        name = "Unison Detune",
        group = "Unison",
        min = 0.0,
        max = 1.0,
        default = 0.2,
        step = 0.001
    )]
    pub unison_detune: f64,

    #[param(
        id = "unison_blend",
        name = "Unison Blend",
        group = "Unison",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.001
    )]
    pub unison_blend: f64,

    #[param(
        id = "stereo_spread",
        name = "Stereo Spread",
        group = "Unison",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub stereo_spread: f64,

    #[param(
        id = "phase",
        name = "Phase",
        group = "Phase",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub phase: f64,

    #[param(
        id = "random_phase",
        name = "Random Phase",
        group = "Phase",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.001
    )]
    pub random_phase: f64,

    #[param(
        id = "distortion_type",
        name = "Distortion Type",
        group = "Distortion",
        default = DistortionType::None
    )]
    pub distortion_type: DistortionType,

    #[param(
        id = "distortion_amount",
        name = "Distortion Amount",
        group = "Distortion",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub distortion_amount: f64,

    #[param(
        id = "morph_type",
        name = "Spectral Morph",
        group = "Morph",
        default = SpectralMorphType::None
    )]
    pub morph_type: SpectralMorphType,

    #[param(
        id = "morph_amount",
        name = "Morph Amount",
        group = "Morph",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub morph_amount: f64,

    #[param(
        id = "destination",
        name = "Filter Destination",
        group = "Routing",
        default = FilterDestination::Both
    )]
    pub destination: FilterDestination,

    buffer: Vec<Vec<f64>>,
}

impl Default for WavetableOsc {
    fn default() -> Self {
        Self::base_default()
    }
}

#[karbeat_plugin]
#[derive(Clone)]
pub struct NoiseOsc {
    #[param(id = "on", name = "Noise On", group = "Noise", default = 0.0)]
    pub enabled: bool,

    #[param(
        id = "level",
        name = "Noise Level",
        group = "Noise",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub level: f64,

    #[param(
        id = "pan",
        name = "Noise Pan",
        group = "Noise",
        min = -1.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub pan: f64,

    #[param(id = "color", name = "Noise Color", group = "Noise", default = NoiseColor::White)]
    pub color: NoiseColor,

    #[param(
        id = "destination",
        name = "Filter Destination",
        group = "Noise",
        default = FilterDestination::Both
    )]
    pub destination: FilterDestination,
}

impl Default for NoiseOsc {
    fn default() -> Self {
        Self::base_default()
    }
}

#[derive(Clone, PartialEq, Debug, Copy, Deserialize, Serialize, EnumParam)]
pub enum FilterType {
    Lp12,
    Lp24,
    Hp12,
    Hp24,
    Bp12,
    Bp24,
    Notch,
    Comb,
    Formant,
}

#[karbeat_plugin]
#[derive(Clone)]
pub struct FilterParams {
    #[param(id = "on", name = "On", group = "Filter", default = 1.0)]
    pub enabled: bool,

    #[param(id = "type", name = "Filter Type", group = "Filter", default = FilterType::Lp12)]
    pub filter_type: FilterType,

    // MIDI-note-scaled cutoff (0-127); mapped to Hz with an exponential curve
    #[param(
        id = "cutoff",
        name = "Cutoff",
        group = "Filter",
        min = 0.0,
        max = 127.0,
        default = 90.0,
        step = 0.01
    )]
    pub cutoff_note: f64,

    #[param(
        id = "resonance",
        name = "Resonance",
        group = "Filter",
        min = 0.0,
        max = 1.0,
        default = 0.2,
        step = 0.001
    )]
    pub resonance: f64,

    #[param(
        id = "drive",
        name = "Drive",
        group = "Filter",
        min = 0.0,
        max = 30.0,
        default = 0.0,
        step = 0.01
    )]
    pub drive_db: f64,

    #[param(
        id = "mix",
        name = "Mix",
        group = "Filter",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.001
    )]
    pub mix: f64,

    #[param(
        id = "key_track",
        name = "Key Track",
        group = "Filter",
        min = -1.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub key_track: f64,
}

impl Default for FilterParams {
    fn default() -> Self {
        Self::base_default()
    }
}

#[karbeat_plugin]
#[derive(Clone)]
pub struct MacroParams {
    #[param(
        id = "m1",
        name = "Macro 1",
        group = "Macros",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub macro1: f64,

    #[param(
        id = "m2",
        name = "Macro 2",
        group = "Macros",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub macro2: f64,

    #[param(
        id = "m3",
        name = "Macro 3",
        group = "Macros",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub macro3: f64,

    #[param(
        id = "m4",
        name = "Macro 4",
        group = "Macros",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub macro4: f64,
}

impl Default for MacroParams {
    fn default() -> Self {
        Self::base_default()
    }
}

#[karbeat_plugin]
#[derive(Clone)]
pub struct MasterParams {
    #[param(
        id = "volume",
        name = "Master Volume",
        group = "Master",
        min = -60.0,
        max = 12.0,
        default = 0.0,
        step = 0.01
    )]
    pub volume_db: f64,

    #[param(
        id = "pan",
        name = "Master Pan",
        group = "Master",
        min = -1.0,
        max = 1.0,
        default = 0.0,
        step = 0.001
    )]
    pub pan: f64,

    #[param(
        id = "polyphony",
        name = "Polyphony",
        group = "Master",
        min = 1.0,
        max = 64.0,
        default = 16.0,
        step = 1.0
    )]
    pub polyphony: i32,

    #[param(
        id = "glide_time",
        name = "Glide Time",
        group = "Master",
        min = 0.0,
        max = 5.0,
        default = 0.0,
        step = 0.001
    )]
    pub glide_time: f64,

    #[param(
        id = "glide_mode",
        name = "Glide Mode",
        group = "Master",
        default = PortamentoMode::Off
    )]
    pub glide_mode: PortamentoMode,

    #[param(
        id = "pitch_bend_range",
        name = "Pitch Bend Range",
        group = "Master",
        min = 0.0,
        max = 48.0,
        default = 2.0,
        step = 1.0
    )]
    pub pitch_bend_range: i32,

    #[param(
        id = "velocity_sens",
        name = "Velocity Sensitivity",
        group = "Master",
        min = 0.0,
        max = 1.0,
        default = 1.0,
        step = 0.001
    )]
    pub velocity_sensitivity: f64,
}

impl Default for MasterParams {
    fn default() -> Self {
        Self::base_default()
    }
}

#[karbeat_plugin]
#[derive(Clone)]
pub struct DigiWavetableSynth {
    #[nested(prefix = "oscillators")]
    pub oscillators: [WavetableOsc; 2],

    #[nested(prefix = "envelopes")]
    pub envelopes: [AdvancedEnvelopeSettings; 3],

    #[nested(prefix = "lfos")]
    pub lfos: [Lfo; 3],
}

impl Default for DigiWavetableSynth {
    fn default() -> Self {
        Self::base_default()
    }
}

impl DigiWavetableSynth {
    /// Interpolate waveform so that it does not have
    /// phase continuity. we also use hann window to make
    /// it happen
    pub fn interpolate_based_on_pos(&mut self) {}
    //     /// Display the wavetable 2D matrix for visualization
    //     /// in UI screen and the wavetable drawer
    //     pub fn visualize_wavetable(&mut self) -> Vec<Vec<f64>> {

    //     }
}

#[karbeat_macros::auto_param]
impl AudioPlugin for DigiWavetableSynth {
    fn name(&self) -> &str {
        "DigiWavetableSynth"
    }

    fn category(&self) -> karbeat_plugin_api::prelude::PluginCategory {
        PluginCategory::Instrument
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        todo!()
    }

    fn reset(&mut self) {
        todo!()
    }

    fn set_io_layout(
        &mut self,
        inputs: &[karbeat_plugin_api::prelude::BusConfig],
        outputs: &[BusConfig],
    ) {
        let new_channels = outputs.first().map(|b| b.channel_count).unwrap_or(2);
    }

    fn process(
        &mut self,
        buffers: &mut karbeat_plugin_api::prelude::AudioBuffers,
        context: &ProcessContext,
    ) {
        todo!()
    }
}
