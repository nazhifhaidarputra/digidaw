use karbeat_macros::karbeat_plugin;
use karbeat_plugin_api::traits::AudioPlugin;

/// An audio FX to do sidechain compressing,
/// Meaning that the compression is influenced
/// by another input signal
#[karbeat_plugin]
pub struct SidechainCompressor {
    #[param(
        id = "gate_threshold",
        name = "Gate Threshold",
        group = "Gate",
        min = -60.0,
        max = 12.0,
        step = 0.1,
        default = 0.0
    )]
    pub gate_threshold: f32,

    // Expander parameters
    #[param(
        id = "expander_threshold",
        name = "Expander Threshold",
        group = "Expander",
        min = -60.0,
        max = 12.0,
        step = 0.1,
        default = 0.0
    )]
    pub expander_threshold: f32,
    #[param(
        id = "expander_ratio",
        name = "Expander Ratio",
        group = "Expander",
        min = 0.0,
        max = 16.0,
        step = 0.1,
        default = 1.0
    )]
    pub expander_ratio: f32,

    // Compressor parameters
    #[param(
        id = "compressor_threshold",
        name = "Compressor Threshold",
        group = "Compressor",
        min = -60.0,
        max = 12.0,
        step = 0.1,
        default = 0.0
    )]
    pub compressor_threshold: f32,

    #[param(
        id = "compressor_ratio",
        name = "Compressor Ratio",
        group = "Compressor",
        min = 0.0,
        max = 16.0,
        step = 0.1,
        default = 1.0
    )]
    pub compressor_ratio: f32,

    #[param(
        id = "attack",
        name = "Attack",
        group = "Envelope",
        min = 0.1, // Minimum 0.1 ms to prevent instant clipping
        max = 500.0,
        step = 0.1,
        default = 10.0 // 10 ms is a good default
    )]
    pub attack: f32,

    #[param(
        id = "release",
        name = "Release",
        group = "Envelope",
        min = 5.0,
        max = 2000.0, // Up to 2 seconds
        step = 1.0,
        default = 100.0
    )]
    pub release: f32,

    #[param(
        id = "knee",
        name = "Knee Width",
        group = "Compressor",
        min = 0.0, // Hard knee
        max = 24.0, // Very soft knee (width in dB)
        step = 0.1,
        default = 0.0 
    )]
    pub knee: f32,

    #[param(
        id = "makeup_gain",
        name = "Makeup Gain",
        group = "Output",
        min = -24.0,
        max = 24.0,
        step = 0.1,
        default = 0.0
    )]
    pub makeup_gain: f32,

    #[param(
        id = "sc_listen",
        name = "Sidechain Listen",
        group = "Sidechain",
        min = 0.0,
        max = 1.0,
        step = 1.0,
        default = 0.0 // 0.0 = Off, 1.0 = On
    )]
    pub sc_listen: bool,
}

impl AudioPlugin for SidechainCompressor {
    fn name(&self) -> &str {
        todo!()
    }

    fn category(&self) -> karbeat_plugin_api::prelude::PluginCategory {
        todo!()
    }

    fn prepare(&mut self, sample_rate: f32, channels: usize, max_buffer_size: usize) {
        todo!()
    }

    fn reset(&mut self) {
        todo!()
    }

    fn process(&mut self, buffer: &mut [f32], context: &karbeat_plugin_api::prelude::ProcessContext) {
        todo!()
    }

    fn set_parameter(&mut self, id: u32, value: f32) {
        todo!()
    }

    fn get_parameter(&self, id: u32) -> f32 {
        todo!()
    }

    fn apply_automation(&mut self, id: u32, value: f32) {
        todo!()
    }

    fn clear_automation(&mut self, id: u32) {
        todo!()
    }

    fn default_parameters(&self) -> hashbrown::HashMap<u32, f32> {
        todo!()
    }

    fn static_parameter_specs() -> Vec<karbeat_plugin_types::ParameterSpec>
    where
        Self: Sized {
        todo!()
    }

    fn get_parameter_specs(&self) -> Vec<karbeat_plugin_types::ParameterSpec> {
        todo!()
    }

    fn as_any(&self) -> &dyn std::any::Any {
        todo!()
    }
}