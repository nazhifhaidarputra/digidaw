use karbeat_plugin_types::ParameterSpec;
use karbeat_plugins::registry::PluginInfo;

use crate::{
    audio::event::PluginTarget,
    commands::{AudioCommand, EffectTarget},
    context::DawContext,
    core::project::{
        AutomationTarget, EffectAutomationTarget, GeneratorId, GeneratorInstance, MixerChannelParamTarget, TrackAutomationTarget, TrackId, generator::GeneratorInstanceType, mixer::EffectInstance
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

    let specs = ctx.plugin_registry.get_plugin_parameter_specs_by_id(plugin_registry_id);

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

pub fn set_generator_parameter(
    ctx: &mut DawContext,
    generator_id: &GeneratorId,
    param_id: impl IntoParamId,
    value: f32,
) -> Result<(), String> {
    let param_id = param_id.into_id();
    ctx.send_audio_command(AudioCommand::SetGeneratorParameter {
        generator_id: *generator_id,
        param_id,
        value,
    });

    Ok(())
}

pub fn set_generator_parameter_to_default(
    _generator_id: &GeneratorId,
    _param_id: impl IntoParamId,
) {
}

pub fn get_generator_parameter(
    _generator_id: &GeneratorId,
    _param_id: impl IntoParamId,
) -> Result<f32, String> {
    // Parameter tracking has been moved entirely to the audio thread.
    // If Dart needs the value, it should fetch it from the audio thread parameter snapshot.
    Err("ApplicationState no longer tracks parameters in real-time".to_string())
}

pub fn set_effect_parameter(
    ctx: &mut DawContext,
    target: &EffectTarget,
    effect_id: &EffectId,
    param_id: impl IntoParamId,
    value: f32,
) -> Result<(), String> {
    let param_id = param_id.into_id();
    ctx.send_audio_command(AudioCommand::SetEffectParameter {
        target: target.clone(),
        effect_id: *effect_id,
        param_id,
        value,
    });

    Ok(())
}

pub fn query_generator_parameters(ctx: &mut DawContext, generator_id: &GeneratorId) -> Result<(), String> {
    if let Some(sender) = ctx.command_sender.lock().as_mut() {
        sender
            .push(AudioCommand::QueryGeneratorParameters {
                generator_id: *generator_id,
            })
            .map_err(|_| "Command queue full".to_string())?;
        Ok(())
    } else {
        Err("Audio stream not initialized".to_string())
    }
}

pub fn query_effect_parameters(ctx: &mut DawContext, target: &EffectTarget, effect_id: &EffectId) -> Result<(), String> {
    if let Some(sender) = ctx.command_sender.lock().as_mut() {
        let _ = sender.push(AudioCommand::QueryEffectParameters {
            target: target.clone(),
            effect_id: *effect_id,
        });
        Ok(())
    } else {
        Err("Audio stream not initialized".to_string())
    }
}

// Syncing parameters to state is no longer done in real-time.
pub fn execute_plugin_command_generator(
    ctx: &mut DawContext,
    gen_registry_id: u32,
    command: &str,
    payload_value: &serde_json::Value,
) -> Option<serde_json::Value> {
    let registry = &mut ctx.plugin_registry;
    let (mut plugin, _) = registry.create_plugin_by_id(gen_registry_id)?;
    plugin.execute_custom_command(command, payload_value)
}

pub fn execute_plugin_command_effect(
    ctx: &mut DawContext,
    effect_registry_id: u32,
    command: &str,
    payload_value: &serde_json::Value,
) -> Option<serde_json::Value> {
    let registry = &mut ctx.plugin_registry;
    let (mut plugin, _) = registry.create_plugin_by_id(effect_registry_id)?;
    plugin.execute_custom_command(command, payload_value)
}

pub fn execute_effect_instance_command(
    ctx: &DawContext,
    target: &EffectTarget,
    effect_id: &EffectId,
    command: &str,
    payload_value: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let app = &ctx.app_state;

    let (plugin_name, plugin_registry_id, plugin_state) = match target {
        EffectTarget::Track(track_id) => {
            let channel = app
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
            (
                effect.instance.name.clone(),
                effect.instance.registry_id,
                effect.instance.plugin_state.clone(),
            )
        }
        EffectTarget::Bus(bus_id) => {
            let bus = app
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
            (
                effect.instance.name.clone(),
                effect.instance.registry_id,
                effect.instance.plugin_state.clone(),
            )
        }
        EffectTarget::Master => {
            let effect = app
                .mixer
                .master_bus
                .effects
                .iter()
                .find(|e| e.id == *effect_id)
                .ok_or_else(|| format!("Effect {} not found", effect_id.0))?;
            (
                effect.instance.name.clone(),
                effect.instance.registry_id,
                effect.instance.plugin_state.clone(),
            )
        }
    };

    let registry = &ctx.plugin_registry;
    let mut temp_plugin = (registry
        .create_plugin_by_id(plugin_registry_id)
        .map(|(p, _)| p))
    .ok_or_else(|| format!("Effect '{}' not found in registry", plugin_name))?;

    if !plugin_state.is_empty() {
        temp_plugin.set_state(&plugin_state);
    }

    temp_plugin
        .execute_custom_command(command, payload_value)
        .ok_or_else(|| format!("Command '{}' not supported by '{}'", command, plugin_name))
}

pub fn execute_generator_instance_command(
    ctx: &DawContext,
    generator_id: &GeneratorId,
    command: &str,
    payload_value: &serde_json::Value,
) -> Result<serde_json::Value, String> {
    let app = &ctx.app_state;

    let gen_arc = app
        .generator_pool
        .get(generator_id)
        .ok_or_else(|| format!("Generator {} not found", generator_id.0))?;

    let (plugin_name, plugin_registry_id, plugin_state) = match &gen_arc.instance_type {
        GeneratorInstanceType::Plugin(p) => (p.name.clone(), p.registry_id, p.plugin_state.clone()),
        _ => {
            return Err("Generator is not a plugin".into());
        }
    };

    let registry = &ctx.plugin_registry;
    let mut temp_plugin = (registry
        .create_plugin_by_id(plugin_registry_id)
        .map(|(p, _)| p))
    .ok_or_else(|| format!("Generator '{}' not found in registry", plugin_name))?;

    if !plugin_state.is_empty() {
        temp_plugin.set_state(&plugin_state);
    }

    temp_plugin
        .execute_custom_command(command, payload_value)
        .ok_or_else(|| format!("Command '{}' not supported by '{}'", command, plugin_name))
}

// ============================================================================
// Real-time Plugin Command Channel
// ============================================================================

/// Monotonically increasing counter used to generate unique request IDs.
/// Each call to `execute_plugin_command` claims one ID so that the caller
/// can match the eventual `PluginCommandResponse` that arrives on the stream.
static PLUGIN_COMMAND_REQUEST_ID: AtomicU32 = AtomicU32::new(1);

/// Dispatches a custom command to a live plugin instance running on the audio
/// thread. The audio engine will invoke `execute_custom_command` on the
/// target plugin and push an `AudioFeedback::PluginCommandResponse` back
/// through the feedback channel.
///
/// # Parameters
/// - `target`: Which plugin instance to target (Generator, TrackEffect, etc.).
/// - `command`: A string key identifying the command (e.g. `"get_meter"`).
/// - `payload`: Arbitrary JSON value sent as the command argument.
///
/// # Returns
/// `Ok(request_id)` on success. Use this ID to correlate the response that
/// arrives via the feedback stream. Returns `Err` if the audio stream is not
/// initialised or the command queue is full.
pub fn execute_plugin_command(
    ctx: &mut DawContext,
    target: PluginTarget,
    command: String,
    payload: serde_json::Value,
) -> Result<u32, String> {
    let request_id = PLUGIN_COMMAND_REQUEST_ID.fetch_add(1, Ordering::Relaxed);

    if let Some(sender) = ctx.command_sender.lock().as_mut() {
        sender
            .push(AudioCommand::ExecutePluginCommand {
                target,
                command,
                payload,
                request_id,
            })
            .map_err(|_| "Command queue full".to_string())?;
        Ok(request_id)
    } else {
        Err("Audio stream not initialised".to_string())
    }
}


static ZERO_COPY_REQUEST_ID: AtomicU32 = AtomicU32::new(1);

/// Dispatches a command to the audio thread to fetch a ZeroCopyBuffer from a specific plugin.
///
/// # Parameters
/// - `target`: Which plugin instance to target (Generator, TrackEffect, etc.).
/// - `name`: The specific buffer name to request from the plugin (e.g., "spectrum").
///
/// # Returns
/// `Ok(request_id)` on success. Use this ID to correlate the response that
/// arrives via the unified `create_feedback_stream`. Returns `Err` if the audio stream
/// is not initialised or the command queue is full.
pub fn query_zero_copy_buffer_from_live_plugin(
    ctx: &mut DawContext,
    target: PluginTarget,
    name: String,
) -> Result<u32, String> {
    let request_id = ZERO_COPY_REQUEST_ID.fetch_add(1, Ordering::Relaxed);

    if let Some(sender) = ctx.command_sender.lock().as_mut() {
        sender
            .push(AudioCommand::QueryZeroCopyBuffer {
                target,
                name,
                request_id,
            })
            .map_err(|_| "Command queue full".to_string())?;
        Ok(request_id)
    } else {
        Err("Audio stream not initialised".to_string())
    }
}

// =====================================
// Human interaction parameter editing
// =====================================

/// Signals the start of a parameter edit gesture (e.g., user clicks a knob).
pub fn begin_generator_parameter_edit(
    ctx: &mut DawContext,
    generator_id: &GeneratorId,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let param_id = param_id.into_id();
    
    let target = AutomationTarget::Generator {
        generator_id: *generator_id,
        param_id,
    };

    ctx.send_audio_command(AudioCommand::BeginEdit { target })
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

/// Signals the start of an effect parameter edit gesture.
pub fn begin_effect_parameter_edit(
    ctx: &mut DawContext,
    effect_target: &EffectTarget,
    effect_id: &EffectId,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let param_id = param_id.into_id();
    
    let target = match effect_target {
        EffectTarget::Track(track_id) => AutomationTarget::Track {
            track_id: *track_id,
            track_target: TrackAutomationTarget::MixerChannel(
                MixerChannelParamTarget::Plugin { 
                    effect_id: *effect_id, 
                    target: EffectAutomationTarget::PluginParam { param_id } 
                }
            ),
        },
        EffectTarget::Bus(bus_id) => AutomationTarget::Bus {
            bus_id: *bus_id,
            mix_target: MixerChannelParamTarget::Plugin { 
                effect_id: *effect_id, 
                target: EffectAutomationTarget::PluginParam { param_id } 
            },
        },
        EffectTarget::Master => AutomationTarget::Master(
            MixerChannelParamTarget::Plugin { 
                effect_id: *effect_id, 
                target: EffectAutomationTarget::PluginParam { param_id } 
            }
        ),
    };

    ctx.send_audio_command(AudioCommand::BeginEdit { target })
}

/// Signals the end of an effect parameter edit gesture.
pub fn end_effect_parameter_edit(
    ctx: &mut DawContext,
    effect_target: &EffectTarget,
    effect_id: &EffectId,
    param_id: impl IntoParamId,
) -> anyhow::Result<()> {
    let param_id = param_id.into_id();
    
    let target = match effect_target {
        EffectTarget::Track(track_id) => AutomationTarget::Track {
            track_id: *track_id,
            track_target: TrackAutomationTarget::MixerChannel(
                MixerChannelParamTarget::Plugin { 
                    effect_id: *effect_id, 
                    target: EffectAutomationTarget::PluginParam { param_id } 
                }
            ),
        },
        EffectTarget::Bus(bus_id) => AutomationTarget::Bus {
            bus_id: *bus_id,
            mix_target: MixerChannelParamTarget::Plugin { 
                effect_id: *effect_id, 
                target: EffectAutomationTarget::PluginParam { param_id } 
            },
        },
        EffectTarget::Master => AutomationTarget::Master(
            MixerChannelParamTarget::Plugin { 
                effect_id: *effect_id, 
                target: EffectAutomationTarget::PluginParam { param_id } 
            }
        ),
    };

    ctx.send_audio_command(AudioCommand::EndEdit { target })
}