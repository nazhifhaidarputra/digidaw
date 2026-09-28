# Karbeat Plugin System (`karbeat-plugins`, `karbeat-macros`, `karbeat-plugin-api`, `karbeat-plugin-types`)

Welcome to the **Karbeat Audio Plugin Architecture** documentation. This guide explains how audio plugins (Synthesizers and Audio Effects) are authored, structured, automated, and integrated into the DigiDAW audio engine and Flutter UI.

---

## Architecture Overview

The plugin architecture is split into modular crates with clear responsibilities:

```
                      ┌───────────────────────────────┐
                      │        Flutter Frontend       │
                      │  (UI Sliders, Meters, Editors)│
                      └───────────────▲───────────────┘
                                      │ (Manifests & FFI)
┌─────────────────────────────────────┴─────────────────────────────────────┐
│ karbeat-plugins                                                           │
│  First-party effects & instruments, PluginRegistry, Manifest export tool  │
├───────────────────────────────┬───────────────────────────────────────────┤
│ karbeat-macros                │ karbeat-plugin-api                        │
│  #[karbeat_plugin]            │  AudioPlugin (Unified Trait)              │
│  #[auto_param]                │  AudioPluginBuilder, Manifestable         │
│  #[derive(EnumParam)]         │  AudioBuffers, ProcessContext             │
│  #[derive(AutoParams)]        │  PDC (Latency/Tail), Presets, Editor      │
├───────────────────────────────┴───────────────────────────────────────────┤
│ karbeat-plugin-types                                                      │
│  Param<T>, ParamBounds, EnumParam, ParameterSpec, AutoParams reflection   │
└───────────────────────────────────────────────────────────────────────────┘
```

### Crate Breakdown

1. **`karbeat-plugin-types`** (License: Apache-2.0 / MIT)
   - Fundamental types for DSP parameters: `Param<T>`, `ParamBounds<T>`, `NormalizedF64`.
   - Parameter metadata structures (`ParameterSpec`, `ParameterValueType`).
   - The `AutoParams` trait for hierarchical parameter traversal and reflection.
   - Safe dual-value architecture: separates user UI values (`base_value`) from automation-modulated values (`current_value`).

2. **`karbeat-plugin-api`** (License: Apache-2.0 / MIT)
   - Defines the universal `AudioPlugin` trait (replacing legacy `KarbeatEffect`/`KarbeatGenerator`).
   - Non-interleaved channel buffers (`AudioBuffers`), high-precision transport, and sample-accurate automation contexts (`ProcessContext`).
   - Plugin Delay Compensation (PDC) hooks (`latency_samples()`, `tail_samples()`, `has_latency_changed()`).
   - Factory trait `AudioPluginBuilder` and JSON export trait `Manifestable`.

3. **`karbeat-macros`** (License: Apache-2.0 / MIT)
   - Procedural macros that eliminate boilerplate for parameter registration, reflection, automation, and trait implementations:
     - `#[karbeat_plugin]`: Rewrites struct fields into `Param<T>`, assigns stable hashed 32-bit IDs, checks for ID collisions at compile-time, and implements `AutoParams` & `base_default()`.
     - `#[auto_param]`: Implements standard `AudioPlugin` parameter getters/setters/specs with optional `on_change` hooks.
     - `#[derive(EnumParam)]`: Enables Rust enums to be used directly as choice parameters.
     - `#[derive(AutoParams)]`: Allows sub-components to expose `Param<T>` fields recursively.

4. **`karbeat-plugins`** (License: GPL-3.0 with Linking Exception)
   - Contains concrete first-party plugins:
     - **Synths / Generators**: `KarbeatzerV2`, `MyRetro`, `DigiWavetable`.
     - **Effects**: `DigiParametricEQ`, `Pitcher` (real-time pitch shifting), `DigidawSidechainCompressor`, `PeakController`.
   - `PluginRegistry`: Central factory registering plugins and instantiating them by `u32` ID.
   - `export_manifest`: CLI binary that exports JSON parameter schemas for the Flutter frontend.

---

## 1. Parameters in Depth (`karbeat-plugin-types`)

Audio plugins require parameter handling that is both **thread-safe** and **automation-aware**. 

### The Dual-Value Architecture: `base_value` vs `current_value`

In DigiDAW, a parameter wraps two distinct values:
- **`base_value`**: The value set by the user via the UI knob/slider.
- **`current_value`**: The effective value used by the audio DSP thread.

```
       User Turns Knob                  Sequencer Plays Automation
              │                                      │
              ▼                                      ▼
      param.set_base(val)               param.apply_automation(val)
              │                                      │
              ├────────────────────────┐             │
              ▼                        ▼             ▼
      [ base_value ]           [ current_value (effective) ]
                                             │
                                             ▼
                                     param.get() (Audio DSP)
```

- When automation is active, `current_value` is continuously modulated by the timeline automation curve.
- The user's `base_value` remains untouched.
- When automation ends or is cleared (`clear_automation()`), `current_value` snaps back to `base_value`.
- **Latest Feature — `get_current_parameter` vs `get_parameter`**:
  - `get_parameter(id)`: Returns `base_value` (used when saving project presets or updating static UI controls).
  - `get_current_parameter(id)`: Returns the live `current_value` (used by UI meters, visual knobs during automation playback, and engine telemetry).

### Supported Parameter Types (`ParamType`)

The `Param<T>` wrapper supports:
- `f32` and `f64`: Continuous floating-point parameters (supports smoothing via `ParameterSmoother`).
- `i32`: Discrete integer values (e.g., Octave `-2..+2`, Filter Poles `1..4`).
- `bool`: Toggle buttons and on/off switches.
- Any enum implementing `EnumParam` (Choice parameters with display labels).

---

## 2. Macro System (`karbeat-macros`)

Writing parameter getters, setters, serialization bounds, and automation handlers manually is error-prone. `karbeat-macros` automates this entirely.

### `#[derive(EnumParam)]`

Derive this on any enum to use it as a plugin choice parameter:

```rust
use karbeat_macros::EnumParam;

#[derive(Clone, Copy, Debug, PartialEq, EnumParam)]
pub enum FilterMode {
    #[default]
    LowPass,
    HighPass,
    BandPass,
    Notch,
}
```

The macro automatically generates index conversion (`to_index`, `from_index`) and UI string slices (`variants()`).

### `#[karbeat_plugin]`

Apply `#[karbeat_plugin]` to your plugin struct:

```rust
use karbeat_macros::{karbeat_plugin, EnumParam};
use karbeat_dsp::filter::BiquadFilter;

#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct StereoChorus {
    #[param(
        id = "rate",
        name = "Rate",
        group = "Modulation",
        min = 0.1,
        max = 10.0,
        default = 1.5,
        step = 0.01
    )]
    pub rate: f32,

    #[param(
        id = "depth",
        name = "Depth",
        group = "Modulation",
        min = 0.0,
        max = 1.0,
        default = 0.5
    )]
    pub depth: f32,

    #[param(
        id = "sync",
        name = "Tempo Sync",
        group = "Modulation",
        default = false
    )]
    pub sync: bool,

    #[param(
        id = "filter_mode",
        name = "Filter Mode",
        group = "Tone",
        default = FilterMode::LowPass
    )]
    pub filter_mode: FilterMode,

    // Nested DSP sub-module (its parameters will be prefixed with "filter/")
    #[nested(prefix = "filter/")]
    pub filter: BiquadFilter,

    // Internal state (not a parameter, automatically skipped from parameter reflection)
    sample_rate: f32,
    channels: usize,
}
```

#### What `#[karbeat_plugin]` Does Under the Hood:
1. **Field Rewriting**: Rewrites raw types (`rate: f32`) into typed wrappers (`rate: Param<f32>`).
2. **Compile-time Collision Detection**: Verifies that all parameter `id` strings in the struct are unique.
3. **ParamId Enum Generation**: Generates `StereoChorusParamIds` with stable compile-time FNV hashes.
4. **`base_default()` Generator**: Generates `StereoChorus::base_default()` which initializes all `Param<T>` fields with their min, max, default, step, and hash ID, while calling `Default::default()` for nested and non-param fields.
5. **`AutoParams` Trait Implementation**: Implements recursive reflection:
   - `auto_set_parameter(prefix_hash, id, value)`
   - `auto_get_parameter(prefix_hash, id)`
   - `auto_get_current_parameter(prefix_hash, id)` *(Latest feature)*
   - `auto_apply_automation(prefix_hash, id, value)`
   - `auto_clear_automation(prefix_hash, id)`
   - `auto_get_parameter_specs(prefix_hash, prefix_str)`

### `#[nested(prefix = "...")]`

Allows composing complex plugins from smaller DSP blocks:
- The child struct must implement `AutoParams` (using `#[karbeat_plugin]` or `#[derive(AutoParams)]`).
- Supports single structs (`filter: BiquadFilter`) or arrays/iterables (`oscillators: [Oscillator; 3]`).
- Hierarchical parameter paths are created automatically (e.g., `osc0/frequency`, `filter/cutoff`).

### `#[auto_param]`

Apply `#[auto_param]` to your `impl AudioPlugin for ...` block:

```rust
#[auto_param]
impl AudioPlugin for StereoChorus {
    fn name(&self) -> &str {
        "Stereo Chorus"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize) {
        self.sample_rate = sample_rate;
    }

    fn reset(&mut self) {
        // Reset internal buffers
    }

    fn set_io_layout(&mut self, inputs: &[BusConfig], _outputs: &[BusConfig]) {
        self.channels = inputs.first().map(|b| b.channel_count).unwrap_or(2);
    }

    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext) {
        // Read effective parameters using .get()
        let current_rate = self.rate.get();
        let current_depth = self.depth.get();
        // ... DSP processing ...
    }
}
```

#### What `#[auto_param]` Automatically Generates:
- `set_parameter(id, value)` -> delegates to `auto_set_parameter`.
- `get_parameter(id)` -> delegates to `auto_get_parameter`.
- `get_current_parameter(id)` -> delegates to `auto_get_current_parameter`.
- `apply_automation(id, value)` -> delegates to `auto_apply_automation`.
- `clear_automation(id)` -> delegates to `auto_clear_automation`.
- `default_parameters()` -> builds hash map of default values.
- `get_parameter_specs()` & `static_parameter_specs()` -> gathers all UI specifications.
- `as_any()` -> reflection helper for downcasting.

#### Reacting to Parameter Changes: `#[auto_param(on_change = "...")]`

If your plugin needs to recalculate coefficients or internal tables when parameters change:

```rust
#[auto_param(on_change = "self.update_dsp_coefficients()")]
impl AudioPlugin for StereoChorus {
    // ...
}
```

---

## 3. The `AudioPlugin` Trait (`karbeat-plugin-api`)

The `AudioPlugin` trait in `karbeat-plugin-api` is the unified interface powering both synths and effects:

```rust
pub trait AudioPlugin: DynClone + Send + Sync {
    // Metadata
    fn name(&self) -> &str;
    fn category(&self) -> PluginCategory; // PluginCategory::Effect or PluginCategory::Instrument
    fn vendor(&self) -> &str { "DigiDAW" }
    fn version(&self) -> &str { "1.0.0" }

    // Lifecycle & Audio Setup
    fn prepare(&mut self, sample_rate: f32, max_buffer_size: usize);
    fn reset(&mut self);
    fn can_apply_io_layout(&self, inputs: &[BusConfig], outputs: &[BusConfig]) -> bool;
    fn set_io_layout(&mut self, inputs: &[BusConfig], outputs: &[BusConfig]);

    // Real-Time Audio Callback
    fn process(&mut self, buffers: &mut AudioBuffers, context: &ProcessContext);

    // Latency & PDC
    fn latency_samples(&self) -> u32 { 0 }
    fn tail_samples(&self) -> u32 { 0 }
    fn has_latency_changed(&mut self) -> bool { false }

    // Parameter Accessors (Provided by #[auto_param])
    fn set_parameter(&mut self, id: u32, value: f32);
    fn get_parameter(&self, id: u32) -> f32;
    fn get_current_parameter(&self, id: u32) -> f32;
    fn apply_automation(&mut self, id: u32, value: f32);
    fn clear_automation(&mut self, id: u32);
    fn get_parameter_specs(&self) -> Vec<ParameterSpec>;
    fn static_parameter_specs() -> Vec<ParameterSpec> where Self: Sized;

    // Presets & State Persistence
    fn get_state(&self) -> Vec<u8>;
    fn set_state(&mut self, state: &[u8]);
}
```

### Real-time Audio Rules for `process()`

In accordance with [`AGENTS.md`](file:///home/the_great_anoa/Projects/digidaw/AGENTS.md) and [`CONTRIBUTING.md`](file:///home/the_great_anoa/Projects/digidaw/CONTRIBUTING.md), the real-time audio thread has strict constraints:
- **No Heap Allocations**: Never call `Vec::new()`, `Box::new()`, `String`, or grow collections in `process()`.
- **No Blocking / Locks**: Never acquire mutex locks, sleep, or perform filesystem or network I/O.
- **Pre-allocate Buffers**: Allocate and resize delay lines, tables, and scratch buffers inside `prepare()` or `set_io_layout()`.
- **Non-interleaved Channels**: Audio is passed as `AudioBuffers`, where `buffers.main_inputs[0].channel_data[channel]` gives `&[f32]` per channel.

---

## 4. Complete Walkthrough: Building a Plugin

Here is a full, working example of a Stereo Gain / Tremolo effect:

```rust
use karbeat_macros::{auto_param, karbeat_plugin};
use karbeat_plugin_api::prelude::*;
use karbeat_utils::hash::hash_str;

#[karbeat_plugin]
#[derive(Clone, Debug)]
pub struct TremoloEffect {
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

    #[param(
        id = "lfo_rate",
        name = "LFO Rate",
        group = "Tremolo",
        min = 0.1,
        max = 20.0,
        default = 4.0,
        step = 0.1
    )]
    pub lfo_rate: f32,

    #[param(
        id = "lfo_depth",
        name = "LFO Depth",
        group = "Tremolo",
        min = 0.0,
        max = 1.0,
        default = 0.0,
        step = 0.01
    )]
    pub lfo_depth: f32,

    // Internal state
    sample_rate: f32,
    phase: f32,
}

impl Default for TremoloEffect {
    fn default() -> Self {
        let mut inst = Self::base_default();
        inst.sample_rate = 44100.0;
        inst.phase = 0.0;
        inst
    }
}

#[auto_param]
impl AudioPlugin for TremoloEffect {
    fn name(&self) -> &str {
        "DigiDAW Tremolo"
    }

    fn category(&self) -> PluginCategory {
        PluginCategory::Effect
    }

    fn prepare(&mut self, sample_rate: f32, _max_buffer_size: usize) {
        self.sample_rate = sample_rate;
    }

    fn reset(&mut self) {
        self.phase = 0.0;
    }

    fn set_io_layout(&mut self, _inputs: &[BusConfig], _outputs: &[BusConfig]) {}

    fn process(&mut self, buffers: &mut AudioBuffers, _context: &ProcessContext) {
        if buffers.main_inputs.is_empty() || buffers.main_outputs.is_empty() {
            return;
        }

        let gain = self.gain.get();
        let rate = self.lfo_rate.get();
        let depth = self.lfo_depth.get();

        let num_frames = buffers.main_outputs[0].channel_data[0].len();
        let phase_inc = (rate * 2.0 * std::f32::consts::PI) / self.sample_rate;

        let input_bus = &buffers.main_inputs[0];
        let output_bus = &mut buffers.main_outputs[0];
        let num_channels = input_bus.channel_data.len().min(output_bus.channel_data.len());

        for i in 0..num_frames {
            let tremolo_mod = 1.0 - depth * (0.5 * (1.0 + self.phase.sin()));
            let total_gain = gain * tremolo_mod;

            for ch in 0..num_channels {
                output_bus.channel_data[ch][i] = input_bus.channel_data[ch][i] * total_gain;
            }

            self.phase += phase_inc;
            if self.phase > 2.0 * std::f32::consts::PI {
                self.phase -= 2.0 * std::f32::consts::PI;
            }
        }
    }
}

impl AudioPluginBuilder for TremoloEffect {
    fn build() -> Self {
        Self::default()
    }
}

impl Manifestable for TremoloEffect {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: hash_str("effect_tremolo"),
            id_string: "effect_tremolo".to_string(),
            name: "DigiDAW Tremolo".to_string(),
            internal_type: "TremoloEffect".to_string(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}
```

---

## 5. Plugin Registration & Flutter Integration Pipeline

Once a plugin is implemented, follow these 3 steps to make it available in DigiDAW and generate its Flutter UI controls:

### Step 1: Register in `PluginRegistry`

In [`rust/karbeat-plugins/src/registry.rs`](file:///home/the_great_anoa/Projects/digidaw/rust/karbeat-plugins/src/registry.rs):

```rust
pub fn new_with_defaults() -> Self {
    let mut registry = Self::new();
    register_plugins!(
        registry,
        ("synth_karbeatzer_v2", "Karbeatzer V2", KarbeatzerV2),
        ("effect_param_eq", "Parametric EQ", DigiParametricEQ),
        // Add your plugin:
        ("effect_tremolo", "Tremolo", TremoloEffect),
    );
    registry
}
```

### Step 2: Export JSON Manifest

Add your plugin type to the `export_plugins!` list in [`rust/karbeat-plugins/src/bin/export_manifest.rs`](file:///home/the_great_anoa/Projects/digidaw/rust/karbeat-plugins/src/bin/export_manifest.rs):

```rust
export_plugins!(
    export_dir,
    MyRetro,
    KarbeatzerV2,
    DigiParametricEQ,
    Pitcher,
    DigidawSidechainCompressor,
    TremoloEffect // <-- Added here
);
```

Run the manifest extractor:
```sh
PLUGIN_MANIFEST_DIR="../assets/manifests/audio-plugins/" cargo run --bin export_manifest
```
This generates a clean JSON specification in `assets/manifests/audio-plugins/effects/tremolo_effect.manifest.json`.

### Step 3: Generate Typed Dart Plugin Classes

Run the Dart generator from the repository root:
```sh
dart run lib/tool/generate_plugin_manifests.dart
```
This automatically produces a strongly-typed Dart parameter specification in `lib/generated/plugins/tremolo.dart` and exports it in `lib/generated/plugins/plugins.dart`.

The Flutter UI can now dynamically render sliders, knobs, and automation curves matching your Rust parameters with zero manual wiring!

---

## 6. Testing & Validation

To test and verify plugin crates:

```sh
# Run tests across all plugin crates
cargo test -p karbeat-plugins -p karbeat-macros -p karbeat-plugin-types -p karbeat-plugin-api

# Run Clippy checks
cargo clippy -p karbeat-plugins -p karbeat-macros -p karbeat-plugin-types -p karbeat-plugin-api

# Verify manifest export
PLUGIN_MANIFEST_DIR="../assets/manifests/audio-plugins/" cargo run --bin export_manifest
```
