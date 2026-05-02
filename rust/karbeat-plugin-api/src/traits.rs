use std::{any::Any, fmt::Debug};

use hashbrown::HashMap;

use karbeat_plugin_types::ParameterSpec;
use serde_json::Value;

use crate::types::{PluginCategory, ProcessContext};

// ============================================================================
// CONTEXTS & TYPES
// ============================================================================



pub trait KarbeatPlugin: Send + Sync {
    fn name(&self) -> &str;
    
    /// Tells the host what kind of plugin this is for track routing
    fn category(&self) -> PluginCategory;

    fn prepare(&mut self, sample_rate: f32, channels: usize, max_buffer_size: usize);
    fn reset(&mut self);

    /// The universal process block.
    /// - Instruments will ignore the incoming audio in the buffer and overwrite it.
    /// - Effects will modify the audio in the buffer.
    fn process(&mut self, buffer: &mut [f32], context: &ProcessContext);

    // --- State & Automation ---
    fn set_parameter(&mut self, id: u32, value: f32);
    fn get_parameter(&self, id: u32) -> f32;
    fn apply_automation(&mut self, id: u32, value: f32);
    fn clear_automation(&mut self, id: u32);
    fn default_parameters(&self) -> HashMap<u32, f32>;
    
    fn static_parameter_specs() -> Vec<ParameterSpec> where Self: Sized;
    fn get_parameter_specs(&self) -> Vec<ParameterSpec>;

    /// Save/Restore state
    fn get_state(&self) -> Vec<u8> { Vec::new() }
    fn set_state(&mut self, _state: &[u8]) {}

    // --- DAW Integration Properties ---
    fn latency_samples(&self) -> u32 { 0 }
    fn tail_samples(&self) -> u32 { 0 }

    fn execute_custom_command(&mut self, _command: &str, _payload: &Value) -> Option<Value> { None }
    fn as_any(&self) -> &dyn Any;
}

impl Debug for dyn KarbeatPlugin + Send + Sync {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("KarbeatPlugin")
            .field("name", &self.name())
            .field("category", &self.category())
            .finish()
    }
}

/// A standard factory trait for instantiating Karbeat plugins.
pub trait AudioPluginBuilder {
    /// Creates a fresh, default instance of the plugin.
    fn build() -> Self;
}
