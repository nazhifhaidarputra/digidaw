use karbeat_plugin_types::ParameterSpec;
use karbeat_plugins::registry::PluginInfo;

use crate::{
    audio::{engine::PluginTelemetrySnapshot, event::PluginTarget},
    commands::{AudioCommand, EffectTarget},
    context::DawContext,
    core::project::{
        generator::GeneratorInstanceType, mixer::EffectInstance, AutomationTarget,
        EffectAutomationTarget, GeneratorId, GeneratorInstance, MixerChannelParamTarget,
        TrackAutomationTarget, TrackId,
    },
    shared::id::*,
};

use std::sync::atomic::{AtomicU32, Ordering};

// ============================================================================
// PARAMETER ID RESOLVER
// ============================================================================

/// Helper trait to allow the API to accept either raw u32 hashes or UI string paths.
pub trait IntoParamId {
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

pub fn get_available_generators<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&PluginInfo) -> U,
    C: FromIterator<U>,
{
    ctx.plugin_registry
        .list_generators_with_ids()
        .iter()
        .map(mapper)
        .collect()
}

pub fn get_available_effects<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&PluginInfo) -> U,
    C: FromIterator<U>,
{
    ctx.plugin_registry
        .list_effects_with_ids()
        .iter()
        .map(mapper)
        .collect()
}

pub fn get_available_plugins<P, C>(ctx: &DawContext) -> C
where
    P: From<PluginInfo>,
    C: FromIterator<P>,
{
    ctx.plugin_registry
        .list_plugins_with_ids()
        .into_iter()
        .map(|p| P::from(p))
        .collect()
}

pub fn get_generator<M, U>(ctx: &DawContext, generator_id: &GeneratorId, mapper: M) -> Option<U>
where
    M: FnOnce(&GeneratorInstance) -> U,
{
    let generator = ctx.app_state.generator_pool.get(generator_id)?;
    Some(mapper(generator))
}

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

    let channel = app.mixer.channels.get(track_id)?;

    let effect = channel
        .channel
        .effects
        .iter()
        .find(|e| e.id == *effect_id)?;

    Some(mapper(effect))
}

pub fn get_effect_from_master<M, U>(ctx: &DawContext, effect_id: &EffectId, mapper: M) -> Option<U>
where
    M: FnOnce(&EffectInstance) -> U,
{
    let channel = &ctx.app_state.mixer.master_bus;
    let effect = channel.effects.iter().find(|e| e.id == *effect_id)?;
    Some(mapper(effect))
}

pub fn get_effects_from_track<C, U, M>(ctx: &DawContext, track_id: &TrackId, mapper: M) -> Option<C>
where
    M: Fn(&EffectInstance) -> U,
    C: FromIterator<U>,
{
    let channel = ctx.app_state.mixer.channels.get(track_id)?;

    Some(channel.channel.effects.iter().map(mapper).collect())
}

pub fn get_master_effects<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&EffectInstance) -> U,
    C: FromIterator<U>,
{
    let channel = &ctx.app_state.mixer.master_bus;
    channel.effects.iter().map(mapper).collect()
}

pub fn get_generator_parameter_specs<F, T>(
    ctx: &DawContext,
    generator_id: &GeneratorId,
    mapper: F,
) -> Result<Vec<T>, String>
where
    F: Fn(ParameterSpec, f32) -> T,
{
    let generator_arc = ctx
        .app_state
        .generator_pool
        .get(generator_id)
        .ok_or_else(|| format!("Generator {} not found", generator_id.0))?;

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

pub fn get_effect_parameter_specs<F, T>(
    ctx: &DawContext,
    target: &EffectTarget,
    effect_id: &EffectId,
    mapper: F,
) -> Result<Vec<T>, String>
where
    F: Fn(ParameterSpec, f32) -> T,
{
    let (plugin_name, plugin_registry_id) = match target {
        EffectTarget::Track(track_id) => {
            let channel = ctx
                .app_state
                .mixer
                .channels
                .get(track_id)
                .ok_or_else(|| format!("Track channel {} not found", track_id.0))?;
            let effect = channel
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id.0))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        EffectTarget::Bus(bus_id) => {
            let bus = ctx
                .app_state
                .mixer
                .buses
                .get(bus_id)
                .ok_or_else(|| format!("Bus {} not found", bus_id.0))?;
            let effect = bus
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id.0))?;
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
                .ok_or_else(|| format!("Effect {} not found", effect_id.0))?;
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
    let (plugin_name, plugin_registry_id) = match target {
        PluginTarget::Generator(gen_id) => {
            let gen = ctx
                .app_state
                .generator_pool
                .get(gen_id)
                .ok_or_else(|| anyhow::anyhow!("Generator {} not found", gen_id.0))?;

            if let GeneratorInstanceType::Plugin(ref p) = gen.instance_type {
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
                .get(track_id)
                .ok_or_else(|| anyhow::anyhow!("Track {} not found", track_id.0))?;
            let effect = channel
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id.0))?;
            (effect.instance.name.clone(), effect.instance.registry_id)
        }
        PluginTarget::BusEffect(bus_id, effect_id) => {
            let bus = ctx
                .app_state
                .mixer
                .buses
                .get(bus_id)
                .ok_or_else(|| anyhow::anyhow!("Bus {} not found", bus_id.0))?;
            let effect = bus
                .channel
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id.0))?;
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
                .ok_or_else(|| anyhow::anyhow!("Effect {} not found", effect_id.0))?;
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

    let command = match target {
        PluginTarget::Generator(gen_id) => AudioCommand::SetGeneratorParameter {
            generator_id: *gen_id,
            param_id,
            value,
        },
        PluginTarget::TrackEffect(track_id, effect_id) => AudioCommand::SetEffectParameter {
            target: EffectTarget::Track(*track_id),
            effect_id: *effect_id,
            param_id,
            value,
        },
        PluginTarget::BusEffect(bus_id, effect_id) => AudioCommand::SetEffectParameter {
            target: EffectTarget::Bus(*bus_id),
            effect_id: *effect_id,
            param_id,
            value,
        },
        PluginTarget::MasterEffect(effect_id) => AudioCommand::SetEffectParameter {
            target: EffectTarget::Master,
            effect_id: *effect_id,
            param_id,
            value,
        },
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
        PluginTarget::MasterEffect(effect_id) => {
            AutomationTarget::Master(MixerChannelParamTarget::Plugin {
                effect_id: *effect_id,
                target: EffectAutomationTarget::PluginParam { param_id },
            })
        }
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
    let (mut plugin, _) = ctx.plugin_registry.create_plugin_by_id(registry_id)?;
    plugin.execute_custom_command(command, payload_value)
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
            let gen = ctx
                .app_state
                .generator_pool
                .get(gen_id)
                .ok_or_else(|| anyhow::anyhow!("Generator {} not found", gen_id.0))?;
            match &gen.instance_type {
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
                .get(t_id)
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
                .get(b_id)
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
    .ok_or_else(|| anyhow::anyhow!("Plugin '{}' not found in registry", plugin_name))?;

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
