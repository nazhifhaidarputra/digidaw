use karbeat_plugin_api::types::BusConfig;
use karbeat_plugins::registry::PluginFactory;

use crate::{commands::PreparedPluginTelemetry, core::project::plugin::PluginInstance};

/// Builds a first-party plugin processor restored to `plugin`'s saved state and parameters.
pub fn prepare_builtin_plugin(
    factory: PluginFactory,
    plugin: &PluginInstance,
    sample_rate: u32,
    block_size: usize,
) -> (
    Box<dyn karbeat_plugin_api::traits::AudioPlugin>,
    PreparedPluginTelemetry,
) {
    let mut prepared = factory();
    if plugin.plugin_state.is_empty() {
        // Without captured state the spec values are all that was persisted.
        for spec in &plugin.parameter_specs {
            prepared.set_parameter(spec.id, spec.value as f32);
        }
    } else {
        // Saving stores the registry's specs beside the state, and their values are the
        // defaults, so applying them as well would undo every restored edit.
        prepared.set_state(&plugin.plugin_state);
    }
    prepared.prepare(sample_rate as f32, block_size.max(512));
    let bus = BusConfig {
        name: "Main".into(),
        channel_count: 2,
        is_optional: false,
    };
    prepared.set_io_layout(std::slice::from_ref(&bus), std::slice::from_ref(&bus));
    let telemetry = PreparedPluginTelemetry::new(prepared.as_ref());
    (prepared, telemetry)
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "test fixtures use registered first-party plugins"
)]
mod tests {
    use super::*;
    use karbeat_plugins::registry::PluginRegistry;
    use karbeat_utils::hash::hash_str;

    #[test]
    fn saved_state_survives_the_default_specs_stored_beside_it() {
        let registry = PluginRegistry::new_with_defaults();
        for plugin in ["effect_param_eq", "effect_delay", "synth_my_retro"] {
            let registry_id = hash_str(plugin);
            let (factory, name) = registry.create_plugin_by_id(registry_id).unwrap();
            let mut live = factory();
            for spec in live.get_parameter_specs() {
                let edited = spec.default_value + (spec.max - spec.default_value) * 0.5;
                live.set_parameter(spec.id, edited as f32);
            }
            // What a save writes: the live state plus the registry's specs at their defaults.
            let saved = PluginInstance {
                plugin_state: live.get_state(),
                parameter_specs: registry
                    .get_plugin_parameter_specs_by_id(registry_id)
                    .unwrap(),
                ..PluginInstance::new_with_id(registry_id, &name)
            };
            let (restored, _) = prepare_builtin_plugin(factory, &saved, 48_000, 512);
            let untouched = factory();
            let mut edited = 0;
            for spec in live.get_parameter_specs() {
                let expected = live.get_parameter(spec.id);
                assert!(
                    (restored.get_parameter(spec.id) - expected).abs() < 1e-4,
                    "{plugin} {}: expected {expected}, restored {}",
                    spec.path,
                    restored.get_parameter(spec.id)
                );
                if (untouched.get_parameter(spec.id) - expected).abs() > 1e-4 {
                    edited += 1;
                }
            }
            assert!(edited > 0, "{plugin} fixture edited no parameter");
        }
    }

    #[test]
    fn spec_values_restore_an_instance_saved_without_state() {
        let registry = PluginRegistry::new_with_defaults();
        let registry_id = hash_str("effect_param_eq");
        let (factory, name) = registry.create_plugin_by_id(registry_id).unwrap();
        let mut specs = registry
            .get_plugin_parameter_specs_by_id(registry_id)
            .unwrap();
        let gain = specs
            .iter_mut()
            .find(|spec| spec.path == "base_gain")
            .unwrap();
        gain.value = 6.0;
        let gain = gain.id;
        let saved = PluginInstance {
            parameter_specs: specs,
            ..PluginInstance::new_with_id(registry_id, &name)
        };
        let (restored, _) = prepare_builtin_plugin(factory, &saved, 48_000, 512);
        assert!((restored.get_parameter(gain) - 6.0).abs() < 1e-4);
    }
}
