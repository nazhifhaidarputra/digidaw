pub use dyn_clone::{DynClone, clone_trait_object};
pub use hashbrown::HashMap;
use karbeat_plugin_types::ParameterSpec;
pub use serde_json::Value;
use std::{any::Any, fmt::Debug};

// Import the newly defined types for non-interleaved audio and IO configuration
use crate::types::{AudioBuffers, BusConfig, PluginCategory, ProcessContext, ZeroCopyBuffer};

// ============================================================================
// CONTEXTS & TYPES
// ============================================================================

use raw_window_handle::RawWindowHandle;

/// Handles the GUI layer of the plugin.
/// This lives entirely on the main UI thread.
pub trait PluginEditor {
    /// Instructs the plugin to attach its GUI to the provided platform-specific window handle.
    /// Returns true if successful.
    fn open(&mut self, handle: RawWindowHandle) -> bool;

    /// Instructs the plugin to destroy its GUI resources.
    fn close(&mut self);

    /// Gets the current or preferred dimensions of the GUI (width, height).
    fn get_size(&self) -> Option<(u32, u32)>;

    /// Requests the plugin to resize its GUI. Returns true if accepted.
    fn set_size(&mut self, width: u32, height: u32) -> bool;
}

/// ## Overview
///
/// Interface or Trait every plugin should respect.
/// If you want your plugin to work as intended,
/// You should implement all the interface
/// available in this trait.
///
/// ## Note
///
/// We don't specify a certain way to implement this interface.
/// All the logic used is up to you, and the performance
/// of the computation is your responsibility.
///
/// This trait is now fully aligned with VST3/CLAP capabilities,
/// supporting non-interleaved audio, sample-accurate automation,
/// parameter gestures, and rich transport context.
pub trait AudioPlugin: DynClone + Send + Sync {
    // --- Metadata ---
    fn name(&self) -> &str;
    fn category(&self) -> PluginCategory;

    /// Optional: Vendor name (Useful for VST3/CLAP adapters)
    fn vendor(&self) -> &str {
        "Unknown Vendor"
    }

    /// Optional: Plugin version (Useful for VST3/CLAP adapters)
    fn version(&self) -> &str {
        "1.0.0"
    }

    /// Prepares the plugin for processing.
    /// Note: `channels` is no longer passed here. Use `set_io_layout` to configure channels.
    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize);

    /// Define this reset for a graceful cleanup of the plugin
    fn reset(&mut self);

    /// Asks the plugin if it can support a specific IO layout.
    /// The adapter/engine calls this when routing changes.
    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool {
        true // Default: accept any layout
    }

    /// Tells the plugin to apply the new IO layout.
    /// The plugin should reset its internal state if the channel count changed.
    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]);

    /// The universal process block.
    /// - Instruments will ignore the incoming audio in the buffer and overwrite it.
    /// - Effects will modify the audio in the buffer.
    ///
    /// Now accepts non-interleaved `AudioBuffers` and a rich `ProcessContext`
    /// containing sample-accurate param changes and high-precision transport.
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext);

    /// Tells the plugin to bypass. It should let its internal tails ring out.
    fn set_bypass(&mut self, _bypass: bool) {}

    /// The engine can poll this every block to see if it needs to recalculate PDC.
    fn has_latency_changed(&mut self) -> bool {
        false
    }

    /// Report the latency of the plugin to the audio engine in samples.
    fn latency_samples(&self) -> u32 {
        0
    }

    /// Report the tail of the plugin to the audio engine in samples.
    fn tail_samples(&self) -> u32 {
        0
    }

    fn set_parameter(&mut self, id: u32, value: f32);
    fn get_parameter(&self, id: u32) -> f32;

    /// Returns the effective value currently used by DSP, including automation.
    /// External plugins may fall back to their regular parameter getter.
    fn get_current_parameter(&self, id: u32) -> f32 {
        self.get_parameter(id)
    }

    /// Called when the user starts touching a parameter in the UI.
    /// Crucial for the host to draw automation curves correctly.
    fn begin_parameter_edit(&mut self, _id: u32) {}

    /// Called when the user releases the parameter.
    fn end_parameter_edit(&mut self, _id: u32) {}

    // --- Parameter Normalization & UI Formatting ---
    // VST3/CLAP strictly separate 0..1 normalized values from plain values (e.g. Hz, dB).

    /// Converts a plain value (e.g., 1000.0 Hz) to a normalized value (0.0..1.0).
    fn plain_to_normalized(&self, id: u32, plain: f32) -> f32 {
        plain
    }

    /// Converts a normalized value (0.0..1.0) to a plain value (e.g., 1000.0 Hz).
    fn normalized_to_plain(&self, id: u32, normalized: f32) -> f32 {
        normalized
    }

    /// Formats a normalized value as a string for UI display (e.g., "1.00 kHz").
    fn value_to_string(&self, id: u32, normalized: f32) -> String {
        format!("{:.2}", self.normalized_to_plain(id, normalized))
    }

    /// Parses a string from the UI into a normalized value.
    fn string_to_value(&self, id: u32, text: &str) -> Option<f32> {
        text.parse::<f32>()
            .ok()
            .map(|p| self.plain_to_normalized(id, p))
    }

    // Internal engine modulation (kept for your engine's specific modulation matrix)
    fn apply_automation(&mut self, id: u32, value: f32);
    fn clear_automation(&mut self, id: u32);

    fn default_parameters(&self) -> HashMap<u32, f32>;

    fn static_parameter_specs() -> Vec<ParameterSpec>
    where
        Self: Sized;

    fn get_parameter_specs(&self) -> Vec<ParameterSpec>;

    // --- State & Presets ---

    /// Get state of plugin when loading preset / saving project
    fn get_state(&self) -> Vec<u8> {
        let mut current_params: HashMap<u32, f32> = HashMap::new();

        let specs = self.get_parameter_specs();
        for spec in specs {
            current_params.insert(spec.id, self.get_parameter(spec.id));
        }

        rmp_serde::to_vec(&current_params).unwrap_or_else(|err| {
            log::error!("Failed to serialize Plugin state: {}", err);
            Vec::new()
        })
    }

    /// Set state of plugin when saving plugin state / loading project
    fn set_state(&mut self, state: &[u8]) {
        if state.is_empty() {
            return;
        }

        match rmp_serde::from_slice::<HashMap<u32, f32>>(state) {
            Ok(saved_params) => {
                for (id, value) in saved_params {
                    self.set_parameter(id, value);
                }
            }
            Err(err) => {
                log::error!("Failed to deserialize Plugin state: {}", err);
            }
        }
    }

    /// Returns a list of factory presets (Name and the raw state chunk).
    /// If your plugin doesn't have internal presets, return an empty Vec.
    fn get_factory_presets(&self) -> Vec<(String, Vec<u8>)> {
        Vec::new()
    }

    /// Loads a specific preset by index.
    fn load_preset(&mut self, _index: usize) {}

    /// Gets the index of the currently loaded preset, if any.
    fn current_preset_index(&self) -> Option<usize> {
        None
    }

    // --- Custom & FFI ---

    /// Execute a custom command
    fn execute_custom_command(&mut self, _command: &str, _payload: &Value) -> Option<Value> {
        None
    }

    /// Allows the plugin to expose a shared memory buffer by name
    fn get_zero_copy_buffer(&self, _name: &str) -> Option<ZeroCopyBuffer> {
        None // Default implementation does nothing
    }

    // --- Reflection ---

    /// An helper to enable downcasting
    fn as_any(&self) -> &dyn Any;

    // --- GUI Handler ----
    /// Returns the UI editor for this plugin, if it has one.
    /// The DAW will call this from the main thread, take ownership of the editor,
    /// and use it to draw the GUI.
    fn get_editor(&mut self) -> Option<Box<dyn PluginEditor>> {
        None
    }
}

impl Debug for dyn AudioPlugin + Send + Sync {
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

clone_trait_object!(AudioPlugin);
