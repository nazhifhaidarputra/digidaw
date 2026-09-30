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
    if !plugin.plugin_state.is_empty() {
        prepared.set_state(&plugin.plugin_state);
    }
    for spec in &plugin.parameter_specs {
        prepared.set_parameter(spec.id, spec.value as f32);
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
