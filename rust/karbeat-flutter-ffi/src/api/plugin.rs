use crate::api::plugins::PluginTelemetrySnapshotDto;
use crate::api::{mixer::UiEffectInstance, project::UiGeneratorInstance};
use flutter_rust_bridge::frb;
use karbeat_core::api::plugin_api::{self, IntoParamId};
use karbeat_core::audio::event::PluginTarget;
use karbeat_core::context::DawContext;
use karbeat_core::core::project::TrackId;
use karbeat_core::plugin_types::ParameterValueType;
use karbeat_core::shared::id::*;
use karbeat_plugins::registry::PluginInfo;
use karbeat_utils::parser::FromPluginCommand;
pub use parking_lot::Mutex;
use std::sync::Arc;

// ============================================================================
// UI TYPES FOR FLUTTER RUST BRIDGE
// ============================================================================

/// Parameter type enum for FRB
#[derive(Clone, Copy, Debug, PartialEq)]
pub enum UiParameterType {
    Float,
    Int,
    Bool,
    Choice,
}

impl From<ParameterValueType> for UiParameterType {
    fn from(value: ParameterValueType) -> Self {
        match value {
            ParameterValueType::Float => UiParameterType::Float,
            ParameterValueType::Int => UiParameterType::Int,
            ParameterValueType::Bool => UiParameterType::Bool,
            ParameterValueType::Choice => UiParameterType::Choice,
        }
    }
}

/// Plugin parameter description for UI generation
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPluginParameter {
    pub id: u32,
    pub path: String,
    pub name: String,
    pub group: String,
    pub value: f32,
    pub min: f32,
    pub max: f32,
    pub default_value: f32,
    pub step: f32,
    pub param_type: UiParameterType,
    pub choices: Vec<String>,
}

#[derive(Clone, Debug)]
pub enum UiParamId {
    Id(u32),
    Path(String),
}

impl UiParamId {
    /// Resolves the FRB enum into the raw u32 hash expected by the audio thread
    pub fn resolve(self) -> u32 {
        match self {
            UiParamId::Id(id) => id,
            UiParamId::Path(path) => karbeat_utils::hash::hash_str(&path),
        }
    }
}

impl IntoParamId for UiParamId {
    fn into_id(self) -> u32 {
        match self {
            UiParamId::Id(id) => id,
            UiParamId::Path(path) => karbeat_utils::hash::hash_str(&path),
        }
    }
}

// ============================================================================
// TARGET IDENTIFICATION
// ============================================================================

/// Identifies which live plugin instance on the audio thread to target.
/// Mirrors `karbeat_core::audio::event::PluginTarget` for FRB exposure.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub enum UiPluginTarget {
    /// A generator plugin identified by its GeneratorId
    Generator(u32),
    /// A track effect identified by (TrackId, EffectId)
    TrackEffect { track_id: u32, effect_id: u32 },
    /// A bus effect identified by (BusId, EffectId)
    BusEffect { bus_id: u32, effect_id: u32 },
    /// An effect on the master bus
    MasterEffect(u32),
}

impl From<UiPluginTarget> for PluginTarget {
    fn from(val: UiPluginTarget) -> Self {
        match val {
            UiPluginTarget::Generator(id) => PluginTarget::Generator(GeneratorId::from(id)),
            UiPluginTarget::TrackEffect {
                track_id,
                effect_id,
            } => PluginTarget::TrackEffect(TrackId::from(track_id), EffectId::from(effect_id)),
            UiPluginTarget::BusEffect { bus_id, effect_id } => {
                PluginTarget::BusEffect(BusId::from(bus_id), EffectId::from(effect_id))
            }
            UiPluginTarget::MasterEffect(id) => PluginTarget::MasterEffect(EffectId::from(id)),
        }
    }
}

impl From<&PluginTarget> for UiPluginTarget {
    fn from(value: &PluginTarget) -> Self {
        match value {
            PluginTarget::Generator(generator_id) => Self::Generator(generator_id.to_u32()),
            PluginTarget::TrackEffect(track_id, effect_id) => Self::TrackEffect {
                track_id: track_id.to_u32(),
                effect_id: effect_id.to_u32(),
            },
            PluginTarget::BusEffect(bus_id, effect_id) => Self::BusEffect {
                bus_id: bus_id.to_u32(),
                effect_id: effect_id.to_u32(),
            },
            PluginTarget::MasterEffect(effect_id) => Self::MasterEffect(effect_id.to_u32()),
        }
    }
}

// ============================================================================
// PLUGIN METADATA & REGISTRY API
// ============================================================================

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub enum KarbeatPluginType {
    Generator,
    Effect,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPluginInfo {
    pub id: u32,
    pub name: String,
    pub plugin_type: KarbeatPluginType,
}

#[frb(ignore)]
impl UiPluginInfo {
    pub fn from_info_to_synth(info: &PluginInfo) -> Self {
        Self {
            id: info.id,
            name: info.name.clone(),
            plugin_type: KarbeatPluginType::Generator,
        }
    }

    pub fn from_info_to_effect(info: &PluginInfo) -> Self {
        Self {
            id: info.id,
            name: info.name.clone(),
            plugin_type: KarbeatPluginType::Effect,
        }
    }
}

impl From<&PluginInfo> for UiPluginInfo {
    fn from(p: &PluginInfo) -> Self {
        let plugin_type = match p.is_synth {
            true => KarbeatPluginType::Generator,
            false => KarbeatPluginType::Effect,
        };
        Self {
            id: p.id,
            name: p.name.clone(),
            plugin_type,
        }
    }
}

impl From<PluginInfo> for UiPluginInfo {
    fn from(p: PluginInfo) -> Self {
        let plugin_type = match p.is_synth {
            true => KarbeatPluginType::Generator,
            false => KarbeatPluginType::Effect,
        };
        Self {
            id: p.id,
            name: p.name.clone(),
            plugin_type,
        }
    }
}

/// Get all available generators with their registry IDs (preferred for UI)
pub fn get_available_generators_with_ids(ctx: &DawContext) -> Result<Vec<UiPluginInfo>, String> {
    Ok(plugin_api::get_available_generators(ctx, |plugin_info| {
        UiPluginInfo::from_info_to_synth(plugin_info)
    }))
}

/// Get all available effects with their registry IDs (preferred for UI)
pub fn get_available_effects_with_ids(ctx: &DawContext) -> Result<Vec<UiPluginInfo>, String> {
    Ok(plugin_api::get_available_effects(ctx, |plugin_info| {
        UiPluginInfo::from_info_to_effect(plugin_info)
    }))
}

pub fn get_available_plugins_with_ids(ctx: &DawContext) -> Vec<UiPluginInfo> {
    plugin_api::get_available_plugins::<UiPluginInfo, _>(ctx)
}

/// Get a single generator state from the Generator Pool
pub fn get_generator(ctx: &DawContext, generator_id: u32) -> Result<UiGeneratorInstance, String> {
    let gen_id = GeneratorId::from(generator_id);
    let gen_instance = plugin_api::get_generator(ctx, &gen_id, |g| UiGeneratorInstance::from(g))
        .ok_or_else(|| format!("Generator {} not found", generator_id))?;
    Ok(gen_instance)
}

pub fn get_effect(
    ctx: &DawContext,
    track_id: u32,
    effect_id: u32,
) -> Result<UiEffectInstance, String> {
    let track_id = TrackId::from(track_id);
    let effect_id = EffectId::from(effect_id);
    plugin_api::get_effect(ctx, &track_id, &effect_id, |e| UiEffectInstance::from(e))
        .ok_or_else(|| format!("Effect {} not found", effect_id.0))
}

pub fn get_effect_from_master(
    ctx: &DawContext,
    effect_id: u32,
) -> Result<UiEffectInstance, String> {
    let effect_id_typed = EffectId::from(effect_id);
    plugin_api::get_effect_from_master(ctx, &effect_id_typed, |e| UiEffectInstance::from(e))
        .ok_or_else(|| format!("Effect {} not found", effect_id))
}

pub fn get_effects_from_track(
    ctx: &DawContext,
    track_id: u32,
) -> Result<Vec<UiEffectInstance>, String> {
    let track_id = TrackId::from(track_id);
    plugin_api::get_effects_from_track(ctx, &track_id, |e| UiEffectInstance::from(e))
        .ok_or_else(|| format!("Track {} not found", track_id.0))
}

pub fn get_master_effects(ctx: &DawContext) -> Vec<UiEffectInstance> {
    plugin_api::get_master_effects(ctx, |e| UiEffectInstance::from(e))
}

// ============================================================================
// UNIFIED PARAMETER MANIPULATION API
// ============================================================================

/// Get parameter specifications for ANY plugin type (Generator or Effect)
pub fn get_plugin_parameter_specs(
    ctx: &DawContext,
    target: UiPluginTarget,
) -> Result<Vec<UiPluginParameter>, String> {
    let plugin_target = target.into();

    plugin_api::get_plugin_parameter_specs(ctx, &plugin_target, |p, value| {
        UiPluginParameter {
            id: p.id,
            path: p.path,
            name: p.name,
            group: p.group,
            value,
            min: p.min as f32,
            max: p.max as f32,
            default_value: p.default_value as f32,
            step: p.step as f32,
            param_type: UiParameterType::from(p.value_type),
            choices: p.choices,
        }
    })
    .map_err(|e| e.to_string())
}

/// Set a parameter on ANY plugin type (Generator or Effect)
pub fn set_plugin_parameter(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    param_id: UiParamId,
    value: f32,
) -> Result<(), String> {
    plugin_api::set_plugin_parameter(ctx, &target.into(), param_id.resolve(), value)
        .map_err(|e| e.to_string())
}

/// Signals the start of a parameter edit gesture (e.g., user clicks a knob)
pub fn begin_plugin_parameter_edit(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    param_id: UiParamId,
) -> Result<(), String> {
    plugin_api::begin_plugin_parameter_edit(ctx, &target.into(), param_id.resolve())
        .map_err(|e| e.to_string())
}

/// Signals the end of a parameter edit gesture (e.g., user releases a knob)
pub fn end_plugin_parameter_edit(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    param_id: UiParamId,
) -> Result<(), String> {
    plugin_api::end_plugin_parameter_edit(ctx, &target.into(), param_id.resolve())
        .map_err(|e| e.to_string())
}

// ============================================================================
// CUSTOM PLUGIN COMMAND API
// ============================================================================

/// A response message arriving from the audio thread to Flutter.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiPluginCommandResponse {
    pub request_id: u32,
    pub response_json: String,
}

#[frb(ignore)]
pub fn parse_plugin_response<T: FromPluginCommand>(json_str: &str) -> Result<T, String> {
    let payload: serde_json::Value = serde_json::from_str(json_str)
        .map_err(|e| format!("Failed to parse JSON string: {}", e))?;

    T::from_json(&payload)
}

/// 1. STATELESS COMMANDS (Operates on defaults from the Registry)
pub fn execute_plugin_command_by_registry_id(
    ctx: &mut DawContext,
    registry_id: u32,
    command: String,
    payload_json: String,
) -> Option<String> {
    let payload_value: serde_json::Value =
        serde_json::from_str(&payload_json).unwrap_or(serde_json::json!({}));

    plugin_api::execute_plugin_command_by_registry_id(ctx, registry_id, &command, &payload_value)
        .map(|v| v.to_string())
}

/// 2. STATEFUL COMMANDS (Operates on active instances via Main Thread Sync)
pub fn execute_plugin_instance_command(
    ctx: &DawContext,
    target: UiPluginTarget,
    command: String,
    payload_json: String,
) -> Result<String, String> {
    let payload_value: serde_json::Value =
        serde_json::from_str(&payload_json).unwrap_or(serde_json::json!({}));

    plugin_api::execute_plugin_instance_command(
        ctx,
        &target.into(),
        &command,
        &payload_value,
    )
    .map(|v| v.to_string())
    .map_err(|e| e.to_string())
}

/// 3. REAL-TIME COMMANDS (Dispatched to the audio thread)
pub fn execute_live_plugin_command(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    command: String,
    payload_json: String,
) -> Result<u32, String> {
    let payload: serde_json::Value =
        serde_json::from_str(&payload_json).unwrap_or(serde_json::json!({}));

    plugin_api::execute_live_plugin_command(ctx, target.into(), command, payload)
        .map_err(|e| e.to_string())
}

// ============================================================================
// ZERO-QUEUE / LOCK-FREE TELEMETRY API
// ============================================================================

/// Get the snapshot telemetry from the audio engine. 
/// This utilizes an atomic ArcSwap which enables lock-free reading.
/// If empty, it means that the snapshot is not currently available.
#[frb(sync)]
pub fn get_plugin_snapshot_telemetry_sync(
    ctx: &mut DawContext, 
    target: UiPluginTarget
) -> Option<PluginTelemetrySnapshotDto> {
    plugin_api::get_plugin_telemetry_sync(ctx, target.into()).map(|t| t.into())
}

/// Start or stop the telemetry packing for a specific plugin on the audio thread.
pub fn set_plugin_telemetry_subs(
    ctx: &mut DawContext,
    target: UiPluginTarget,
    buffers: Vec<String>,
    active: bool,
) -> Result<(), String> {
    plugin_api::set_plugin_telemetry_subs(ctx, target.into(), buffers, active)
        .map_err(|e| e.to_string())
}