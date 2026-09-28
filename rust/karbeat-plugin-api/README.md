# Karbeat Plugin API

This crate defines the core traits, lifecycle interfaces, and context objects for audio plugins in the DigiDAW (Karbeat) engine.

👉 **For the comprehensive developer guide with macros and full examples, see: [karbeat-plugins README](../karbeat-plugins/README.md)**

---

## Overview

In the modern Karbeat plugin architecture, both **Effects** and **Synthesizers/Generators** implement the unified [`AudioPlugin`](./src/traits.rs) trait. The category is declared via `plugin.category()`:

- `PluginCategory::Effect`: Processes existing audio from input buses into output buses.
- `PluginCategory::Instrument`: Generates sound into output buses (e.g. synths, samplers).

---

## 1. Core Trait: `AudioPlugin`

The trait definition lives in [`src/traits.rs`](./src/traits.rs):

```rust
pub trait AudioPlugin: DynClone + Send + Sync {
    // --- Metadata ---
    fn name(&self) -> &str;
    fn category(&self) -> PluginCategory;
    fn vendor(&self) -> &str { "DigiDAW" }
    fn version(&self) -> &str { "1.0.0" }

    // --- Audio Lifecycle ---
    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize);
    fn reset(&mut self);
    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool { true }
    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]);

    // --- Real-time DSP Callback ---
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext);

    // --- Plugin Delay Compensation (PDC) & Bypass ---
    fn set_bypass(&mut self, _bypass: bool) {}
    fn has_latency_changed(&mut self) -> bool { false }
    fn latency_samples(&self) -> u32 { 0 }
    fn tail_samples(&self) -> u32 { 0 }

    // --- Parameter Accessors ---
    fn set_parameter(&mut self, id: u32, value: f32);
    fn get_parameter(&self, id: u32) -> f32;

    /// Returns the effective value currently used by DSP, including real-time automation.
    fn get_current_parameter(&self, id: u32) -> f32 {
        self.get_parameter(id)
    }

    // --- Parameter Gestures & Automation ---
    fn begin_parameter_edit(&mut self, _id: u32) {}
    fn end_parameter_edit(&mut self, _id: u32) {}
    fn apply_automation(&mut self, id: u32, value: f32);
    fn clear_automation(&mut self, id: u32);

    // --- Parameter Specifications ---
    fn default_parameters(&self) -> HashMap<u32, f32>;
    fn get_parameter_specs(&self) -> Vec<ParameterSpec>;
    fn static_parameter_specs() -> Vec<ParameterSpec> where Self: Sized;

    // --- State Persistence & Presets ---
    fn get_state(&self) -> Vec<u8>;
    fn set_state(&mut self, state: &[u8]);
    fn get_factory_presets(&self) -> Vec<(String, Vec<u8>)> { Vec::new() }
    fn load_preset(&mut self, _index: usize) {}
    fn current_preset_index(&self) -> Option<usize> { None }

    // --- Reflection & Custom Commands ---
    fn as_any(&self) -> &dyn Any;
    fn execute_custom_command(&mut self, _command: &str, _payload: &Value) -> Option<Value> { None }
    fn get_zero_copy_buffer(&self, _name: &str) -> Option<ZeroCopyBuffer> { None }
    fn get_editor(&mut self) -> Option<Box<dyn PluginEditor>> { None }
}
```

---

## 2. Parameter System & Macro Automation

Rather than implementing all parameter methods manually, combine [`karbeat_macros`](../karbeat-macros/) and [`karbeat_plugin_types`](../karbeat-plugin-types/):

1. Decorate your struct with `#[karbeat_plugin]`:
   - Annotate fields with `#[param(id = "...", name = "...", min = ..., max = ..., default = ...)]`.
   - Sub-modules use `#[nested(prefix = "...")]`.
   - Generates `base_default()` and the `AutoParams` trait reflection.

2. Decorate your `AudioPlugin` implementation with `#[auto_param]`:
   - Automatically fulfills: `set_parameter`, `get_parameter`, `get_current_parameter`, `apply_automation`, `clear_automation`, `default_parameters`, `get_parameter_specs`, `static_parameter_specs`, and `as_any`.
   - Optionally trigger callbacks on parameter change: `#[auto_param(on_change = "self.recompute()")]`.

### Minimal Example

```rust
use karbeat_macros::{auto_param, karbeat_plugin};
use karbeat_plugin_api::prelude::*;

#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct SimpleGain {
    #[param(
        id = "gain",
        name = "Gain",
        group = "Master",
        min = 0.0,
        max = 2.0,
        default = 1.0,
        step = 0.01
    )]
    pub gain: f32,
}

impl Default for SimpleGain {
    fn default() -> Self {
        Self::base_default()
    }
}

#[auto_param]
impl AudioPlugin for SimpleGain {
    fn name(&self) -> &str {
        "Simple Gain"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, _sample_rate: f32, _max_buffer_size: usize) {}
    fn reset(&mut self) {}
    fn set_io_layout(&mut self, _inputs: &[BusConfig], _outputs: &[BusConfig]) {}

    fn process(&mut self, buffers: &mut AudioBuffers, _context: &ProcessContext) {
        let gain = self.gain.get(); // Reads the live, automation-applied value
        if let (Some(input), Some(output)) = (buffers.main_inputs.first(), buffers.main_outputs.first_mut()) {
            for (in_ch, out_ch) in input.channel_data.iter().zip(output.channel_data.iter_mut()) {
                for (src, dst) in in_ch.iter().zip(out_ch.iter_mut()) {
                    *dst = *src * gain;
                }
            }
        }
    }
}

impl AudioPluginBuilder for SimpleGain {
    fn build() -> Self {
        Self::default()
    }
}

impl Manifestable for SimpleGain {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: karbeat_utils::hash::hash_str("effect_simple_gain"),
            id_string: "effect_simple_gain".to_string(),
            name: "Simple Gain".to_string(),
            internal_type: "SimpleGain".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}
```

---

## 3. Supporting Traits

- **`AudioPluginBuilder`**: Factory trait for instantiation (`fn build() -> Self`).
- **`Manifestable`**: Exports plugin schema to JSON for Flutter UI synchronization via `export_manifest(&dir)`.
- **`PluginEditor`**: Interface for hosting native or platform window GUI views.