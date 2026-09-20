use karbeat_plugin_types::ParameterSpec;
use karbeat_plugins::registry::PluginInfo;

use crate::{
    audio::{engine::PluginTelemetrySnapshot, event::PluginTarget},
    commands::{AudioCommand, EffectTarget},
    context::DawContext,
    core::project::{
        AutomationTarget, EffectAutomationTarget, GeneratorId, GeneratorInstance,
        MasterAutomationTarget, MixerChannelParamTarget, TrackAutomationTarget, TrackId,
        generator::GeneratorInstanceType, mixer::EffectInstance,
    },
    shared::id::*,
};

use std::sync::atomic::{AtomicU32, Ordering};

// ============================================================================
// PARAMETER ID RESOLVER
// ============================================================================

/// Helper trait to allow the API to accept either raw u32 hashes or UI string paths.
pub trait IntoParamId {
    /// Resolves this value to the stable numeric parameter identifier used by the audio engine.
    fn into_id(self) -> u32;
}

impl IntoParamId for u32 {
    #[inline(always)]
    fn into_id(self) -> u32 {
        self
    }
}

impl IntoParamId for &str {
    fn into_id(self) -> u32 {
        karbeat_utils::hash::hash_str(self)
    }
}

impl IntoParamId for String {
    fn into_id(self) -> u32 {
        karbeat_utils::hash::hash_str(&self)
    }
}

/// Maps and collects catalog entries identified as instrument generators.
pub fn get_available_generators<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&PluginInfo) -> U,
    C: FromIterator<U>,
{
    ctx.plugin_catalog
        .list()
        .iter()
        .filter(|plugin| plugin.is_synth)
        .map(mapper)
        .collect()
}

/// Maps and collects catalog entries identified as audio effects.
pub fn get_available_effects<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&PluginInfo) -> U,
    C: FromIterator<U>,
{
    ctx.plugin_catalog
        .list()
        .iter()
        .filter(|plugin| !plugin.is_synth)
        .map(mapper)
        .collect()
}

/// Converts and collects every built-in plugin catalog entry.
pub fn get_available_plugins<P, C>(ctx: &DawContext) -> C
where
    P: From<PluginInfo>,
    C: FromIterator<P>,
{
    ctx.plugin_catalog
        .list()
        .into_iter()
        .map(|p| P::from(p))
        .collect()
}

/// Maps a generator instance when `generator_id` exists in the project pool.
pub fn get_generator<M, U>(ctx: &DawContext, generator_id: &GeneratorId, mapper: M) -> Option<U>
where
    M: FnOnce(&GeneratorInstance) -> U,
{
    let generator = ctx.app_state.generator_pool.get(*generator_id)?;
    Some(mapper(generator))
}

/// Maps an effect from a track's mixer channel, returning `None` for either missing identifier.
pub fn get_effect<M, U>(
    ctx: &DawContext,
    track_id: &TrackId,
    effect_id: &EffectId,
    mapper: M,
) -> Option<U>
where
    M: FnOnce(&EffectInstance) -> U,
{
    let app = &ctx.app_state;

    let channel = app.mixer.channels.get(*track_id)?;

    let effect = channel
        .channel
        .effects
        .iter()
        .find(|e| e.id == *effect_id)?;

    Some(mapper(effect))
}

/// Maps an effect in the master bus when the effect identifier exists.
pub fn get_effect_from_master<M, U>(ctx: &DawContext, effect_id: &EffectId, mapper: M) -> Option<U>
where
    M: FnOnce(&EffectInstance) -> U,
{
    let channel = &ctx.app_state.mixer.master_bus;
    let effect = channel.effects.iter().find(|e| e.id == *effect_id)?;
    Some(mapper(effect))
}

/// Maps and collects a track's ordered effect chain, or returns `None` if the track has no channel.
pub fn get_effects_from_track<C, U, M>(ctx: &DawContext, track_id: &TrackId, mapper: M) -> Option<C>
where
    M: Fn(&EffectInstance) -> U,
    C: FromIterator<U>,
{
    let channel = ctx.app_state.mixer.channels.get(*track_id)?;

    Some(channel.channel.effects.iter().map(mapper).collect())
}

/// Maps and collects the master bus's ordered effect chain.
pub fn get_master_effects<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&EffectInstance) -> U,
    C: FromIterator<U>,
{
    let channel = &ctx.app_state.mixer.master_bus;
    channel.effects.iter().map(mapper).collect()
}

/// Returns mapped parameter specifications for a plugin generator.
///
/// External instances use their captured specifications; built-in instances use registry metadata.
/// The value passed to `mapper` is the parameter's default value, not live telemetry.
pub fn get_generator_parameter_specs<F, T>(
    ctx: &DawContext,
    generator_id: &GeneratorId,
    mapper: F,
) -> Result<Vec<T>, String>
where
    F: Fn(ParameterSpec, f32) -> T,
{
    let target = PluginTarget::Generator(*generator_id);
    if super::external_plugin_api::descriptor(ctx, target).is_some() {
        return get_plugin_parameter_specs(ctx, &target, mapper).map_err(|error| error.to_string());
    }
    let generator_arc = ctx
        .app_state
        .generator_pool
        .get(*generator_id)
        .ok_or_else(|| format!("Generator {} not found", generator_id))?;

    let generator = generator_arc;

    if let GeneratorInstanceType::Plugin(ref plugin_instance) = generator.instance_type {
        let specs = ctx
            .plugin_registry
            .get_plugin_parameter_specs_by_id(plugin_instance.registry_id);

        if let Some(specs) = specs {
            let result: Vec<T> = specs
                .into_iter()
                .map(|p| {
                    let value = p.default_value as f32;
                    mapper(p, value)
                })
                .collect();
            Ok(result)
        } else {
            Err(format!(
                "Generator '{}' (registry_id={}) not found in registry",
                plugin_instance.name, plugin_instance.registry_id
            ))
        }
    } else {
        Err("Generator is not a plugin type".to_string())
    }
}

/// Returns mapped parameter specifications for an effect on a track, bus, or master channel.
///
/// The value passed to `mapper` is each specification's default value. Missing channels, effects,
/// or registry entries are reported as descriptive strings.
pub fn get_effect_parameter_specs<F, T>(
    ctx: &DawContext,
    target: &EffectTarget,
    effect_id: &EffectId,
    mapper: F,
) -> Result<Vec<T>, String>
where
    F: Fn(ParameterSpec, f32) -> T,
{
    let plugin_target = match target {
        EffectTarget::Track(id) => PluginTarget::TrackEffect(*id, *effect_id),
        EffectTarget::Bus(id) => PluginTarget::BusEffect(*id, *effect_id),
        EffectTarget::Master => PluginTarget::MasterEffect(*effect_id),
    };
    if super::external_plugin_api::descriptor(ctx, plugin_target).is_some() {
        return get_plugin_parameter_specs(ctx, &plugin_target, mapper).map_err(|error| error.to_string());
    }
    let (plugin_name, plugin_registry_id) = match target {
        EffectTarget::Track(track_id) => {
            let channel = ctx
                .app_state
                .mixer
                .channels
                .get(*track_id)
                .ok_or_else(|| format!("Track channel {} not found", track_id))?;
            let effect = channel
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        EffectTarget::Bus(bus_id) => {
            let bus = ctx
                .app_state
                .mixer
                .buses
                .get(*bus_id)
                .ok_or_else(|| format!("Bus {} not found", bus_id))?;
            let effect = bus
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        EffectTarget::Master => {
            let effect = ctx
                .app_state
                .mixer
                .master_bus
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
    };

    let specs = ctx
        .plugin_registry
        .get_plugin_parameter_specs_by_id(plugin_registry_id);

    if let Some(specs) = specs {
        let result: Vec<T> = specs
            .into_iter()
            .map(|p| {
                let value = p.default_value as f32;
                mapper(p, value)
            })
            .collect();
        Ok(result)
    } else {
        Err(format!(
            "Effect '{}' (registry_id={}) not found in registry",
            plugin_name, plugin_registry_id
        ))
    }
}

// ============================================================================
// UNIFIED PLUGIN STATE & PARAMETER SPECS
// ============================================================================

/// Unified method to get parameter specs for ANY plugin type
pub fn get_plugin_parameter_specs<F, T>(
    ctx: &DawContext,
    target: &PluginTarget,
    mapper: F,
) -> anyhow::Result<Vec<T>>
where
    F: Fn(ParameterSpec, f32) -> T,
{
    if let Some(plugin) = super::external_plugin_api::plugin_instance(ctx, *target).filter(|plugin| plugin.external.is_some()) {
        return Ok(plugin.parameter_specs.iter().cloned().map(|spec| {
            #[allow(clippy::as_conversions, reason = "normalized parameter defaults fit in the engine's f32 value range")]
            let value = spec.default_value as f32;
            mapper(spec, value)
        }).collect());
    }
    let (plugin_name, plugin_registry_id) = match target {
        PluginTarget::Generator(gen_id) => {
            let generator = ctx
                .app_state
                .generator_pool
                .get(*gen_id)
                .ok_or_else(|| anyhow::anyhow!("Generator {} not found", gen_id))?;

            if let GeneratorInstanceType::Plugin(ref p) = generator.instance_type {
                (p.name.clone(), p.registry_id)
            } else {
                return Err(anyhow::anyhow!("Generator is not a plugin type"));
            }
        }
        PluginTarget::TrackEffect(track_id, effect_id) => {
            let channel = ctx
                .app_state
                .mixer
                .channels
                .get(*track_id)
                .ok_or_else(|| anyhow::anyhow!("Track {} not found", track_id))?;
            let effect = channel
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        PluginTarget::BusEffect(bus_id, effect_id) => {
            let bus = ctx
                .app_state
                .mixer
                .buses
                .get(*bus_id)
                .ok_or_else(|| anyhow::anyhow!("Bus {} not found", bus_id))?;
            let effect = bus
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        PluginTarget::MasterEffect(effect_id) => {
            let effect = ctx
                .app_state
                .mixer
                .master_bus
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
    };

    let specs = ctx
        .plugin_registry
        .get_plugin_parameter_specs_by_id(plugin_registry_id)
        .ok_or_else(|| {
            anyhow::anyhow!(
                "Plugin '{}' (registry_id={}) not found in registry",
                plugin_name,
                plugin_registry_id
            )
        })?;

    let result: Vec<T> = specs
        .into_iter()
        .map(|p| {
            let value = p.default_value as f32;
            mapper(p, value)
        })
        .collect();

    Ok(result)
}

// ============================================================================
// UNIFIED PARAMETER MUTATIONS
// ============================================================================

/// Unified method to set a parameter for ANY plugin type
pub fn set_plugin_parameter(
    ctx: &mut DawContext,
    target: &PluginTarget,
    param_id: impl IntoParamId,
    value: f32,
) -> anyhow::Result<()> {
    let param_id = param_id.into_id();

    let command = AudioCommand::SetParameter {
        target: target.clone(),
        param_id,
        value,
    };

    ctx.send_audio_command(command)?;
    Ok(())
}

/// Signals the start of a parameter edit gesture for ANY plugin
pub fn begin_plugin_parameter_edit(
    ctx: &mut DawContext,
    target: &PluginTarget,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let auto_target = map_target_to_automation(target, param_id.into_id());
    ctx.send_audio_command(AudioCommand::BeginEdit {
        target: auto_target,
    })
}

/// Signals the end of a parameter edit gesture for ANY plugin
pub fn end_plugin_parameter_edit(
    ctx: &mut DawContext,
    target: &PluginTarget,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let auto_target = map_target_to_automation(target, param_id.into_id());
    ctx.send_audio_command(AudioCommand::EndEdit {
        target: auto_target,
    })
}

#[inline(always)]
fn map_target_to_automation(target: &PluginTarget, param_id: u32) -> AutomationTarget {
    match target {
        PluginTarget::Generator(id) => AutomationTarget::Generator {
            generator_id: *id,
            param_id,
        },
        PluginTarget::TrackEffect(track_id, effect_id) => AutomationTarget::Track {
            track_id: *track_id,
            track_target: TrackAutomationTarget::MixerChannel(MixerChannelParamTarget::Plugin {
                effect_id: *effect_id,
                target: EffectAutomationTarget::PluginParam { param_id },
            }),
        },
        PluginTarget::BusEffect(bus_id, effect_id) => AutomationTarget::Bus {
            bus_id: *bus_id,
            mix_target: MixerChannelParamTarget::Plugin {
                effect_id: *effect_id,
                target: EffectAutomationTarget::PluginParam { param_id },
            },
        },
        PluginTarget::MasterEffect(effect_id) => AutomationTarget::Master(
            MasterAutomationTarget::MixerChannel(MixerChannelParamTarget::Plugin {
                effect_id: *effect_id,
                target: EffectAutomationTarget::PluginParam { param_id },
            }),
        ),
    }
}

// ============================================================================
// UNIFIED PLUGIN COMMANDS (MAIN THREAD & AUDIO THREAD)
// ============================================================================

/// Executes a command on an uninstantiated plugin straight from the registry
pub fn execute_plugin_command_by_registry_id(
    ctx: &mut DawContext,
    registry_id: u32,
    command: &str,
    payload_value: &serde_json::Value,
) -> Option<serde_json::Value> {
    let (plugin_factory, _) = ctx.plugin_registry.create_plugin_by_id(registry_id)?;
    plugin_factory().execute_custom_command(command, payload_value)
}

/// Executes a command synchronously on the main thread using an instantiated plugin's saved state
pub fn execute_plugin_instance_command(
    ctx: &DawContext,
    target: &PluginTarget,
    command: &str,
    payload_value: &serde_json::Value,
) -> anyhow::Result<serde_json::Value> {
    let (plugin_name, plugin_registry_id, plugin_state) = match target {
        PluginTarget::Generator(gen_id) => {
            let generator = ctx
                .app_state
                .generator_pool
                .get(*gen_id)
                .ok_or_else(|| anyhow::anyhow!("Generator {} not found", gen_id))?;
            match &generator.instance_type {
                GeneratorInstanceType::Plugin(p) => {
                    (p.name.clone(), p.registry_id, p.plugin_state.clone())
                }
                _ => return Err(anyhow::anyhow!("Generator is not a plugin")),
            }
        }
        PluginTarget::TrackEffect(t_id, e_id) => {
            let ch = ctx
                .app_state
                .mixer
                .channels
                .get(*t_id)
                .ok_or_else(|| anyhow::anyhow!("Track not found"))?;
            let ef = ch
                .channel
                .effects
                .iter()
                .find(|e| e.id == *e_id)
                .ok_or_else(|| anyhow::anyhow!("Effect not found"))?;
            (
                ef.instance.name.clone(),
                ef.instance.registry_id,
                ef.instance.plugin_state.clone(),
            )
        }
        PluginTarget::BusEffect(b_id, e_id) => {
            let bus = ctx
                .app_state
                .mixer
                .buses
                .get(*b_id)
                .ok_or_else(|| anyhow::anyhow!("Bus not found"))?;
            let ef = bus
                .channel
                .effects
                .iter()
                .find(|e| e.id == *e_id)
                .ok_or_else(|| anyhow::anyhow!("Effect not found"))?;
            (
                ef.instance.name.clone(),
                ef.instance.registry_id,
                ef.instance.plugin_state.clone(),
            )
        }
        PluginTarget::MasterEffect(e_id) => {
            let ef = ctx
                .app_state
                .mixer
                .master_bus
                .effects
                .iter()
                .find(|e| e.id == *e_id)
                .ok_or_else(|| anyhow::anyhow!("Effect not found"))?;
            (
                ef.instance.name.clone(),
                ef.instance.registry_id,
                ef.instance.plugin_state.clone(),
            )
        }
    };

    let mut temp_plugin = (ctx
        .plugin_registry
        .create_plugin_by_id(plugin_registry_id)
        .map(|(p, _)| p))
    .ok_or_else(|| anyhow::anyhow!("Plugin '{}' not found in registry", plugin_name))?();

    if !plugin_state.is_empty() {
        temp_plugin.set_state(&plugin_state);
    }

    temp_plugin
        .execute_custom_command(command, payload_value)
        .ok_or_else(|| anyhow::anyhow!("Command '{}' not supported by '{}'", command, plugin_name))
}

/// Monotonically increasing counter used to generate unique request IDs.
static PLUGIN_COMMAND_REQUEST_ID: AtomicU32 = AtomicU32::new(1);

/// Dispatches a custom command to a live plugin instance running on the audio thread.
pub fn execute_live_plugin_command(
    ctx: &mut DawContext,
    target: PluginTarget,
    command: String,
    payload: serde_json::Value,
) -> anyhow::Result<u32> {
    let request_id = PLUGIN_COMMAND_REQUEST_ID.fetch_add(1, Ordering::Relaxed);

    ctx.send_audio_command(AudioCommand::ExecutePluginCommand {
        target,
        command,
        payload,
        request_id,
    })?;

    Ok(request_id)
}

// ============================================================================
// ZERO-QUEUE / LOCK-FREE TELEMETRY
// ============================================================================

/// Toggles whether the audio thread should generate and pack telemetry data for this plugin.
pub fn set_plugin_telemetry_subs(
    ctx: &mut DawContext,
    target: PluginTarget,
    buffers: Vec<String>,
    active: bool,
) -> anyhow::Result<()> {
    ctx.send_audio_command(AudioCommand::SetPluginTelemetrySubscription {
        target,
        buffers,
        active,
    })
}

/// Signals the end of a parameter edit gesture (e.g., user releases a knob).
pub fn end_generator_parameter_edit(
    ctx: &mut DawContext,
    generator_id: &GeneratorId,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let param_id = param_id.into_id();

    let target = AutomationTarget::Generator {
        generator_id: *generator_id,
        param_id,
    };

    ctx.send_audio_command(AudioCommand::EndEdit { target })
}

// =============================================================
// ========= NEW shared pointer plugin telemetry getter ========
// =============================================================

/// Synchronously fetches the parameters and buffers for a specific plugin.
pub fn get_plugin_telemetry_sync(
    ctx: &mut DawContext,
    target: PluginTarget,
) -> Option<PluginTelemetrySnapshot> {
    ctx.drain_telemetry_registrations();

    ctx.telemetry_registry
        .as_mut()?
        .param_telemetry_consumers
        .get_mut(&target)
        .map(|consumer| {
            consumer.update();
            consumer.read().clone()
        })
}
