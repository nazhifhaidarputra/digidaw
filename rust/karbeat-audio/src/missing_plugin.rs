use karbeat_plugin_api::{
    prelude::ParameterSpec,
    traits::{AudioPlugin, HashMap},
    types::{AudioBuffers, BusConfig, PluginCategory, ProcessContext},
};

/// Keeps a missing instrument silent or passes through a missing effect's main input.
pub struct MissingPlugin {
    instrument: bool,
}
impl MissingPlugin {
    pub fn instrument() -> Box<dyn AudioPlugin> {
        Box::new(Self { instrument: true })
    }
    pub fn effect() -> Box<dyn AudioPlugin> {
        Box::new(Self { instrument: false })
    }
}
impl AudioPlugin for MissingPlugin {
    fn name(&self) -> &str {
        "Unavailable plugin"
    }
    fn category(&self) -> PluginCategory {
        if self.instrument {
            PluginCategory::Instrument
        } else {
            PluginCategory::Effect
        }
    }
    fn prepare(&mut self, _: f32, _: usize) {}
    fn reset(&mut self) {}
    fn set_io_layout(&mut self, _: &[BusConfig], _: &[BusConfig]) {}
    fn process(&mut self, buffers: &mut AudioBuffers, _: &ProcessContext) {
        for (bus_index, output) in buffers.main_outputs.iter_mut().enumerate() {
            let input = (!self.instrument)
                .then(|| buffers.main_inputs.get(bus_index))
                .flatten();
            for (channel_index, destination) in output.channel_data.iter_mut().enumerate() {
                destination.fill(0.0);
                if let Some(source) = input.and_then(|bus| bus.channel_data.get(channel_index)) {
                    let length = source.len().min(destination.len());
                    destination[..length].copy_from_slice(&source[..length]);
                }
            }
            output.is_silent = input.is_none_or(|bus| bus.is_silent);
        }
    }
    fn set_parameter(&mut self, _: u32, _: f32) {}
    fn get_parameter(&self, _: u32) -> f32 {
        0.0
    }
    fn apply_automation(&mut self, _: u32, _: f32) {}
    fn clear_automation(&mut self, _: u32) {}
    fn default_parameters(&self) -> HashMap<u32, f32> {
        HashMap::new()
    }
    fn static_parameter_specs() -> Vec<ParameterSpec> {
        Vec::new()
    }
    fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
        Vec::new()
    }
    fn as_any(&self) -> &dyn std::any::Any {
        self
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use karbeat_plugin_api::types::{AudioBusBuffer, ProcessingMode};

    #[test]
    fn missing_instrument_silences_and_effect_copies_only_available_input_channels() {
        let context = ProcessContext {
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
        };
        for instrument in [true, false] {
            let mut input = [0.25, -0.5, 0.75];
            let mut left = [f32::NAN; 3];
            let mut right = [f32::NAN; 3];
            let silent;
            {
                let mut inputs = [AudioBusBuffer {
                    channel_data: &mut [&mut input],
                    is_silent: false,
                }];
                let mut outputs = [AudioBusBuffer {
                    channel_data: &mut [&mut left, &mut right],
                    is_silent: false,
                }];
                let mut buffers = AudioBuffers {
                    main_inputs: &mut inputs,
                    main_outputs: &mut outputs,
                    aux_inputs: &mut [],
                    aux_outputs: &mut [],
                };
                MissingPlugin { instrument }.process(&mut buffers, &context);
                silent = buffers.main_outputs[0].is_silent;
            }
            assert_eq!(left, if instrument { [0.0; 3] } else { input });
            assert_eq!(right, [0.0; 3]);
            assert_eq!(silent, instrument);
        }
    }
}
