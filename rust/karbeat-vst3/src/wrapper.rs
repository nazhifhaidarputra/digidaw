use crate::{api::*, context::Vst3HostContext};
use karbeat_plugin_api::{traits::AudioPlugin, types::PluginCategory};
use vst3::{
    Class, ComPtr, ComWrapper, Steinberg::{
        Vst::{IComponent, IEditController}, kNotImplemented, kResultOk,
    },
};

/// Wrapper for VST3 plugin so that it compatibles with karbeat plugin host system
pub struct Vst3Wrapper {
    /// The core DSP processor of the VST3 plugin
    component: ComPtr<IComponent>,

    /// The UI and Parameter controller
    edit_ctrl: Option<ComPtr<IEditController>>,

    /// Keeping COM-wrapped host context alive for the lifetime of the plugin
    _host_context: ComWrapper<Vst3HostContext>,
}

impl Clone for Vst3Wrapper {
    fn clone(&self) -> Self {
        Self {
            component: self.component.clone(),
            edit_ctrl: self.edit_ctrl.clone(),
            _host_context: self._host_context.clone(), 
        }
    }
}

impl AudioPlugin for Vst3Wrapper {
    fn vendor(&self) -> &str {
        "VST3 Vendor"
    }

    fn version(&self) -> &str {
        "1.0.0"
    }

    fn can_apply_io_layout(
        &self,
        inputs: &[karbeat_plugin_api::prelude::BusConfig],
        outputs: &[karbeat_plugin_api::prelude::BusConfig],
    ) -> bool {
        true // Default: accept any layout
    }

    fn set_bypass(&mut self, _bypass: bool) {}

    fn has_latency_changed(&mut self) -> bool {
        false
    }

    fn latency_samples(&self) -> u32 {
        0
    }

    fn tail_samples(&self) -> u32 {
        0
    }

    fn begin_parameter_edit(&mut self, _id: u32) {}

    fn end_parameter_edit(&mut self, _id: u32) {}

    fn plain_to_normalized(&self, id: u32, plain: f32) -> f32 {
        plain
    }

    fn normalized_to_plain(&self, id: u32, normalized: f32) -> f32 {
        normalized
    }

    fn value_to_string(&self, id: u32, normalized: f32) -> String {
        format!("{:.2}", self.normalized_to_plain(id, normalized))
    }

    fn string_to_value(&self, id: u32, text: &str) -> Option<f32> {
        text.parse::<f32>()
            .ok()
            .map(|p| self.plain_to_normalized(id, p))
    }

    fn get_state(&self) -> Vec<u8> {
        // let mut current_params: HashMap<u32, f32> = HashMap::new();

        // let specs = self.get_parameter_specs();
        // for spec in specs {
        //     current_params.insert(spec.id, self.get_parameter(spec.id));
        // }

        // rmp_serde::to_vec(&current_params).unwrap_or_else(|err| {
        //     log::error!("Failed to serialize Plugin state: {}", err);
        //     Vec::new()
        // })
    }

    fn set_state(&mut self, state: &[u8]) {
        // if state.is_empty() {
        //     return;
        // }

        // match rmp_serde::from_slice::<HashMap<u32, f32>>(state) {
        //     Ok(saved_params) => {
        //         for (id, value) in saved_params {
        //             self.set_parameter(id, value);
        //         }
        //     }
        //     Err(err) => {
        //         log::error!("Failed to deserialize Plugin state: {}", err);
        //     }
        // }
    }

    fn get_factory_presets(&self) -> Vec<(String, Vec<u8>)> {
        Vec::new()
    }

    fn load_preset(&mut self, _index: usize) {}

    fn current_preset_index(&self) -> Option<usize> {
        None
    }

    fn execute_custom_command(&mut self, _command: &str, _payload: &Value) -> Option<Value> {
        // VST3 does not have custom command compatibility.
        // We won't implement this
    }

    fn get_zero_copy_buffer(
        &self,
        _name: &str,
    ) -> Option<karbeat_plugin_api::prelude::ZeroCopyBuffer> {
        // VST3 does not have this zero copy buffer compatibility.
        // We won't implement this
        None
    }

    fn get_editor(&mut self) -> Option<Box<dyn karbeat_plugin_api::prelude::PluginEditor>> {
        None
    }

    fn name(&self) -> &str {
        "VST3 Plugin"
    }

    fn category(&self) -> karbeat_plugin_api::prelude::PluginCategory {
        PluginCategory::Effect
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
        outputs: &[karbeat_plugin_api::prelude::BusConfig],
    ) {
        todo!()
    }

    fn process(
        &mut self,
        buffers: &mut karbeat_plugin_api::prelude::AudioBuffers,
        context: &karbeat_plugin_api::prelude::ProcessContext,
    ) {
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

    fn default_parameters(&self) -> HashMap<u32, f32> {
        todo!()
    }

    fn static_parameter_specs() -> Vec<karbeat_plugin_api::prelude::ParameterSpec>
    where
        Self: Sized,
    {
        todo!()
    }

    fn get_parameter_specs(&self) -> Vec<karbeat_plugin_api::prelude::ParameterSpec> {
        todo!()
    }

    fn as_any(&self) -> &dyn std::any::Any {
        todo!()
    }
}
