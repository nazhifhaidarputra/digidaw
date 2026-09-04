use hashbrown::HashMap;
use karbeat_plugin_api::prelude::*;
use serde_json::Value;
use std::{any::Any, fmt::Debug};

// ============================================================================
// FORMAT ENUMERATIONS
// ============================================================================

/// Represents the underlying format of the hosted third-party plugin.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PluginFormat {
    Vst3,
    Clap,
    Lv2,
    Au,
}

/// The wrapper holding the format-specific implementations.
/// Each of plugin wrappers (e.g., `Vst3Wrapper`) will internally
/// implement the `AudioPlugin` trait so we can easily delegate to them.
pub enum PluginWrapper {
    // We use Box<dyn AudioPlugin> here temporarily.
    // Will be replaced with the concrete types,
    // e.g., Vst3(Vst3Wrapper), Clap(ClapWrapper).
    Vst3(Box<dyn AudioPlugin>),
    Clap(Box<dyn AudioPlugin>),
    Lv2(Box<dyn AudioPlugin>),
    Au(Box<dyn AudioPlugin>),
}

// Implement Clone manually to clone the underlying dynamic traits
impl Clone for PluginWrapper {
    fn clone(&self) -> Self {
        match self {
            Self::Vst3(p) => Self::Vst3(dyn_clone::clone_box(&**p)),
            Self::Clap(p) => Self::Clap(dyn_clone::clone_box(&**p)),
            Self::Lv2(p) => Self::Lv2(dyn_clone::clone_box(&**p)),
            Self::Au(p) => Self::Au(dyn_clone::clone_box(&**p)),
        }
    }
}

impl PluginWrapper {
    /// Helper to get a shared reference to the underlying plugin interface
    #[inline(always)]
    pub fn as_plugin(&self) -> &dyn AudioPlugin {
        match self {
            Self::Vst3(p) => p.as_ref(),
            Self::Clap(p) => p.as_ref(),
            Self::Lv2(p) => p.as_ref(),
            Self::Au(p) => p.as_ref(),
        }
    }

    /// Helper to get a mutable reference to the underlying plugin interface
    #[inline(always)]
    pub fn as_plugin_mut(&mut self) -> &mut dyn AudioPlugin {
        match self {
            Self::Vst3(p) => p.as_mut(),
            Self::Clap(p) => p.as_mut(),
            Self::Lv2(p) => p.as_mut(),
            Self::Au(p) => p.as_mut(),
        }
    }
}

// ============================================================================
// UNIVERSAL PLUGIN HOST
// ============================================================================

#[derive(Clone)]
pub struct CachedPluginMetadata {
    name: String,
    category: PluginCategory,
    vendor: String,
    version: String,
}

/// The universal host adapter.
/// Your audio engine will hold this struct, treating it as a standard native plugin.
#[derive(Clone)]
pub struct PluginHost {
    pub format: PluginFormat,
    pub wrapper: PluginWrapper,

    // ======== Cached Metadata =======
    // We cache these at load-time so the audio thread or UI doesn't
    // repeatedly cross the FFI boundary into C++ just to read a string.
    cached_metadata: CachedPluginMetadata,

    is_bypassed: bool,
}

impl PluginHost {
    /// Creates a new PluginHost, caching necessary metadata upfront.
    pub fn new(format: PluginFormat, wrapper: PluginWrapper) -> Self {
        let plugin = wrapper.as_plugin();

        Self {
            format,
            cached_metadata: CachedPluginMetadata {
                name: plugin.name().to_string(),
                category: plugin.category(),
                vendor: plugin.vendor().to_string(),
                version: plugin.version().to_string(),
            },
            wrapper,
            is_bypassed: false,
        }
    }

    /// Returns the format of the hosted plugin
    pub fn format(&self) -> PluginFormat {
        self.format
    }
}

// ============================================================================
// ADAPTER IMPLEMENTATION
// ============================================================================

impl AudioPlugin for PluginHost {
    fn name(&self) -> &str {
        &self.cached_metadata.name
    }

    fn category(&self) -> PluginCategory {
        self.cached_metadata.category.clone()
    }

    fn vendor(&self) -> &str {
        &self.cached_metadata.vendor
    }

    fn version(&self) -> &str {
        &self.cached_metadata.version
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        self.wrapper
            .as_plugin_mut()
            .prepare(sample_rate, max_buffer_size);
    }

    fn reset(&mut self) {
        self.wrapper.as_plugin_mut().reset();
    }

    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool {
        self.wrapper
            .as_plugin()
            .can_apply_io_layout(inputs, outputs)
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]) {
        self.wrapper.as_plugin_mut().set_io_layout(inputs, outputs);
    }

    #[inline(always)]
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        self.wrapper.as_plugin_mut().process(buffers, context);
    }

    fn set_bypass(&mut self, bypass: bool) {
        self.is_bypassed = bypass;
        self.wrapper.as_plugin_mut().set_bypass(bypass);
    }

    fn has_latency_changed(&mut self) -> bool {
        self.wrapper.as_plugin_mut().has_latency_changed()
    }

    fn latency_samples(&self) -> u32 {
        self.wrapper.as_plugin().latency_samples()
    }

    fn tail_samples(&self) -> u32 {
        self.wrapper.as_plugin().tail_samples()
    }

    fn set_parameter(&mut self, id: u32, value: f32) {
        self.wrapper.as_plugin_mut().set_parameter(id, value);
    }

    fn get_parameter(&self, id: u32) -> f32 {
        self.wrapper.as_plugin().get_parameter(id)
    }

    fn get_current_parameter(&self, id: u32) -> f32 {
        self.wrapper.as_plugin().get_current_parameter(id)
    }

    fn begin_parameter_edit(&mut self, id: u32) {
        self.wrapper.as_plugin_mut().begin_parameter_edit(id);
    }

    fn end_parameter_edit(&mut self, id: u32) {
        self.wrapper.as_plugin_mut().end_parameter_edit(id);
    }

    fn plain_to_normalized(&self, id: u32, plain: f32) -> f32 {
        self.wrapper.as_plugin().plain_to_normalized(id, plain)
    }

    fn normalized_to_plain(&self, id: u32, normalized: f32) -> f32 {
        self.wrapper.as_plugin().normalized_to_plain(id, normalized)
    }

    fn value_to_string(&self, id: u32, normalized: f32) -> String {
        self.wrapper.as_plugin().value_to_string(id, normalized)
    }

    fn string_to_value(&self, id: u32, text: &str) -> Option<f32> {
        self.wrapper.as_plugin().string_to_value(id, text)
    }

    fn apply_automation(&mut self, id: u32, value: f32) {
        self.wrapper.as_plugin_mut().apply_automation(id, value);
    }

    fn clear_automation(&mut self, id: u32) {
        self.wrapper.as_plugin_mut().clear_automation(id);
    }

    fn default_parameters(&self) -> HashMap<u32, f32> {
        self.wrapper.as_plugin().default_parameters()
    }

    fn static_parameter_specs() -> Vec<ParameterSpec> {
        // Since a host is dynamic, static parameter specs aren't known at compile time.
        Vec::new()
    }

    fn get_parameter_specs(&self) -> Vec<ParameterSpec> {
        self.wrapper.as_plugin().get_parameter_specs()
    }

    fn get_state(&self) -> Vec<u8> {
        self.wrapper.as_plugin().get_state()
    }

    fn set_state(&mut self, state: &[u8]) {
        self.wrapper.as_plugin_mut().set_state(state);
    }

    fn get_factory_presets(&self) -> Vec<(String, Vec<u8>)> {
        self.wrapper.as_plugin().get_factory_presets()
    }

    fn load_preset(&mut self, index: usize) {
        self.wrapper.as_plugin_mut().load_preset(index);
    }

    fn current_preset_index(&self) -> Option<usize> {
        self.wrapper.as_plugin().current_preset_index()
    }

    fn execute_custom_command(&mut self, command: &str, payload: &Value) -> Option<Value> {
        self.wrapper
            .as_plugin_mut()
            .execute_custom_command(command, payload)
    }

    fn get_zero_copy_buffer(&self, name: &str) -> Option<ZeroCopyBuffer> {
        self.wrapper.as_plugin().get_zero_copy_buffer(name)
    }

    fn as_any(&self) -> &dyn Any {
        self
    }

    fn get_editor(&mut self) -> Option<Box<dyn PluginEditor>> {
        self.wrapper.as_plugin_mut().get_editor()
    }
}
