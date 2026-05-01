# Karbeat Plugin API

This document describes how to implement plugins using the Karbeat Plugin API.

It covers the core traits, helper macros, and how to register your plugin.
More detailed documentation will be added over time.

👉 For complete examples, see: [karbeat-plugins](../karbeat-plugins/)

---

## Overview

A Karbeat plugin can be either:

* **Effect** (audio processing)
* **Generator** (sound source / synth)

Both are defined via traits that you implement.

---

## 1. Core Traits

The base traits are defined in [`traits.rs`](./src/traits.rs).

```rust
pub trait KarbeatEffect: Send + Sync {
    fn name(&self) -> &str;
    // ...
}

pub trait KarbeatGenerator: Send + Sync {
    fn name(&self) -> &str;
    // ...
}
```

### Notes

* You are free to implement the required methods however you like.
* Parameter handling is **fully customizable**, but:

  * The frontend must understand your parameter mapping.
  * Consistency between frontend and backend is your responsibility.

### Recommended Approach

To avoid errors, map parameter IDs (`u32`) using:

* Enums or constants shared across frontend/backend, **or**
* The provided `#[karbeat_plugin]` macro (recommended)

The macro generates stable parameter IDs from string-based identifiers (hashed internally).

---

## 2. Macro Support (`#[karbeat_plugin]`)

Writing parameter boilerplate manually can be tedious.
The `karbeat_macros` crate provides a derive macro to simplify this.

👉 See implementation: [`karbeat-macros`](../karbeat-macros/src/lib.rs)

### Example

```rust
#[derive(Clone)]
#[karbeat_plugin]
pub struct Karbeatzer {
    // IMPORTANT:
    // Nested components must implement AutoParams (from karbeat-plugin-types)
    // Built-in Oscillator already supports this.
    #[nested(prefix = "osc")]
    oscillators: [Oscillator; 3],

    #[param(
        id = "drive",
        name = "Drive",
        group = "Master",
        min = 0.0,
        max = 1.0,
        default = 0.0
    )]
    drive: f32,
}
```

### Generated Helpers

The macro generates helper methods like:

* `auto_set_parameter`
* `auto_get_parameter`
* `auto_apply_automation`
* `auto_clear_automation`
* `auto_get_parameter_specs`

You can delegate your trait implementation to these:

```rust
impl KarbeatGenerator for Karbeatzer {
    fn set_custom_parameter(&mut self, id: u32, value: f32) {
        self.auto_set_parameter(id, value);
    }

    fn get_custom_parameter(&self, id: u32) -> Option<f32> {
        self.auto_get_parameter(id)
    }

    fn apply_automation(&mut self, id: u32, value: f32) {
        self.auto_apply_automation(id, value);
    }

    fn clear_automation(&mut self, id: u32) {
        self.auto_clear_automation(id);
    }

    fn get_parameter_specs(&self) -> Vec<PluginParameter> {
        self.auto_get_parameter_specs()
    }
}
```

---

## 3. Plugin Registration

To register your plugin, your internal engine must implement `Default`.

```rust
impl Default for MyPlugin {
    fn default() -> Self {
        // Your initialization logic
    }
}
```

Then implement the AudioPluginBuilder trait to the plugin:

```rust
impl AudioPluginBuilder for MyPlugin {
    pub fn build() -> Self {
        Self::default();
    }
}
```

And lastly, implement the Manifestable if you want to generate
the plugin JSON manifest

```rust
impl Manifestable for KarbeatParametricEQ {
    fn build_manifest() -> PluginManifest {
        PluginManifest {
            id: 0,
            name: "Karbeat Parametric EQ".into(),
            internal_type: "KarbeatParametricEQ".into(),
            is_synth: false,
            parameters: Self::static_parameter_specs(),
        }
    }
}
```

This enables automatic construction via the registry.

---

## ⚠ Limitations & Notes

### API Stability

* The API is **still in alpha**
* Breaking changes are expected as the system evolves
* Trait definitions and available features may change

---

### Architecture Update

> **Recent change:** Wrapper-based design has been removed.

The system now uses a **modular approach**, which is:

* Easier to maintain
* More flexible for future extensions

At the moment:

* The `karbeat-dsp` crate has limited components
* More utilities and DSP modules will be added progressively

---

## Future Improvements

* More built-in DSP components
* Better documentation and examples
* Stabilized API (post-alpha)

---