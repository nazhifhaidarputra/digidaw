use std::collections::HashMap;

use flutter_rust_bridge::frb;
use karbeat_core::{
    audio::engine::MixerTelemetrySnapshot, commands::MixerChannelSnapshot, shared::id::*,
};
pub use karbeat_core::{
    core::project::TrackId,
    plugin_types::{ParameterSpec, ParameterValueType},
};

use crate::api::plugin::UiPluginTarget;
use karbeat_core::api::mixer_api;
use karbeat_core::commands::MixerChannelTarget;
use karbeat_core::context::DawContext;
use karbeat_core::core::project::mixer::{
    BusMixerChannel, EffectInstance, MixerChannel, MixerChannelParams, MixerState,
    RoutingConnection, RoutingNode,
};

// ======================================
// Type Definitions
// ======================================

// ======================================
// MixerChannelTarget DTO
// ======================================

/// UI-facing mixer channel target — identifies which channel to address.
#[frb]
#[derive(Clone, Debug)]
pub enum UiMixerChannelTarget {
    Track(u32),
    Bus(u32),
    Master,
}

impl From<&UiMixerChannelTarget> for MixerChannelTarget {
    fn from(val: &UiMixerChannelTarget) -> Self {
        match val {
            UiMixerChannelTarget::Track(id) => MixerChannelTarget::Track(TrackId::from(*id)),
            UiMixerChannelTarget::Bus(id) => MixerChannelTarget::Bus(BusId::from(*id)),
            UiMixerChannelTarget::Master => MixerChannelTarget::Master,
        }
    }
}

impl From<MixerChannelTarget> for UiMixerChannelTarget {
    fn from(value: MixerChannelTarget) -> Self {
        match value {
            MixerChannelTarget::Track(track_id) => Self::Track(track_id.into()),
            MixerChannelTarget::Bus(bus_id) => Self::Bus(bus_id.into()),
            MixerChannelTarget::Master => Self::Master,
        }
    }
}

/// Full DSP state snapshot of a mixer channel, polled via
/// poll_mixer_channel_feedback() after calling query_mixer_channel().
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiMixerChannelSnapshot {
    pub target: UiMixerChannelTarget, // u32::MAX for buses, u32::MAX - 1 for master
    /// Post-effects, post-fader peak magnitude in linear amplitude.
    pub magnitude: f32,
    pub volume: f32,
    pub pan: f32,
    pub mute: bool,
    pub solo: bool,
    pub inverted_phase: bool,
}

impl From<MixerChannelSnapshot> for UiMixerChannelSnapshot {
    fn from(m: MixerChannelSnapshot) -> Self {
        Self {
            target: m.target.into(),
            magnitude: m.magnitude,
            volume: m.volume,
            pan: m.pan,
            mute: m.mute,
            solo: m.solo,
            inverted_phase: m.inverted_phase,
        }
    }
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct MixerTelemetrySnapshotDto {
    pub tracks: HashMap<u32, UiMixerChannelSnapshot>,
    pub buses: HashMap<u32, UiMixerChannelSnapshot>,
    pub master: Option<UiMixerChannelSnapshot>,
}

impl From<MixerTelemetrySnapshot> for MixerTelemetrySnapshotDto {
    fn from(snapshot: MixerTelemetrySnapshot) -> Self {
        Self {
            tracks: snapshot
                .tracks
                .iter()
                .map(|(id, snap)| (id.to_u32(), snap.clone().into()))
                .collect(),
            buses: snapshot
                .buses
                .iter()
                .map(|(id, snap)| (id.to_u32(), snap.clone().into()))
                .collect(),
            master: snapshot.master.map(|s| s.into()),
        }
    }
}

/// UI representation of a mixer channel.
/// #[frb(dart_metadata=("freezed"))]
pub struct UiMixerChannel {
    pub volume: f32,
    pub pan: f32,
    pub mute: bool,
    pub solo: bool,
    pub inverted_phase: bool,
    /// List of effect summaries (ID and name).
    pub effects: Vec<UiEffectSummary>,
}

pub struct UiEffectSummary {
    pub id: u32,
    pub registry_id: u32,
    pub name: String,
}

impl From<&MixerChannel> for UiMixerChannel {
    fn from(value: &MixerChannel) -> Self {
        Self {
            // Volume is in dB (both UI and backend use dB)
            volume: value.volume.get(),
            pan: value.pan.get(),
            mute: value.mute,
            solo: value.solo,
            inverted_phase: value.inverted_phase,
            effects: value
                .effects
                .iter()
                .map(|instance| UiEffectSummary {
                    id: instance.id.to_u32(),
                    registry_id: instance.instance.registry_id,
                    name: instance.instance.name.clone(),
                })
                .collect(),
        }
    }
}

/// UI representation of a mixer bus.
#[frb(dart_metadata=("freezed"))]
pub struct UiBus {
    pub id: u32,
    pub name: String,
    pub channel: UiMixerChannel,
}

impl From<&BusMixerChannel> for UiBus {
    fn from(value: &BusMixerChannel) -> Self {
        Self {
            id: value.id.to_u32(),
            name: value.name.clone(),
            channel: (&value.channel).into(),
        }
    }
}

/// UI representation of a routing connection.
#[frb(dart_metadata=("freezed"))]
pub struct UiRoutingConnection {
    pub source: UiRoutingNode,
    pub destination: UiRoutingNode,
    pub send_level: f32,
    pub is_send: bool,
}

impl From<&RoutingConnection> for UiRoutingConnection {
    fn from(value: &RoutingConnection) -> Self {
        Self {
            source: (&value.source).into(),
            destination: (&value.destination).into(),
            send_level: value.send_level,
            is_send: value.is_send,
        }
    }
}

impl From<UiRoutingConnection> for RoutingConnection {
    fn from(value: UiRoutingConnection) -> Self {
        Self {
            source: value.source.into(),
            destination: value.destination.into(),
            send_level: value.send_level,
            is_send: value.is_send,
        }
    }
}

/// UI DTO describing a routing node (Track, Bus, Master).
#[derive(Clone, Debug)]
#[frb]
pub enum UiRoutingNode {
    Track(u32),
    Bus(u32),
    Master,
    PluginSidechain, // this actually useless because the UI does not need this
}

/// A mixer channel that can feed the selected plugin's auxiliary input.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiSidechainSource {
    pub source: UiRoutingNode,
    pub name: String,
    pub enabled: bool,
    pub send_level: f64,
}

impl From<&RoutingNode> for UiRoutingNode {
    fn from(value: &RoutingNode) -> Self {
        match value {
            RoutingNode::Track(id) => UiRoutingNode::Track(id.to_u32()),
            RoutingNode::Bus(id) => UiRoutingNode::Bus(id.to_u32()),
            RoutingNode::Master => UiRoutingNode::Master,
            _ => Self::PluginSidechain,
        }
    }
}

impl From<UiRoutingNode> for RoutingNode {
    fn from(value: UiRoutingNode) -> Self {
        match value {
            UiRoutingNode::Track(id) => RoutingNode::Track(id.into()),
            UiRoutingNode::Bus(id) => RoutingNode::Bus(BusId::from(id)),
            UiRoutingNode::Master => RoutingNode::Master,
            _ => RoutingNode::Master,
        }
    }
}

/// UI representation of the mixer state.
#[frb(dart_metadata=("freezed"))]
pub struct UiMixerState {
    pub channels: HashMap<u32, UiMixerChannel>,
    pub master_bus: UiMixerChannel,
    pub buses: HashMap<u32, UiBus>,
    pub routing: Vec<UiRoutingConnection>,
}

impl From<&MixerState> for UiMixerState {
    fn from(value: &MixerState) -> Self {
        Self {
            channels: value
                .channels
                .iter()
                .map(|(id, channel)| (id.to_u32(), UiMixerChannel::from(&channel.channel)))
                .collect(),
            master_bus: (&value.master_bus).into(),
            buses: value
                .buses
                .iter()
                .map(|(id, bus)| (id.to_u32(), bus.into()))
                .collect(),
            routing: value.routing.iter().map(|c| c.into()).collect(),
        }
    }
}

#[frb(dart_metadata=("freezed"))]
pub struct UiEffectInstance {
    pub id: u32,
    pub name: String,
}

impl From<&EffectInstance> for UiEffectInstance {
    fn from(value: &EffectInstance) -> Self {
        Self {
            id: value.id.to_u32(),
            name: value.instance.name.clone(),
        }
    }
}

impl UiMixerState {
    #[frb(sync)]
    pub fn new() -> Self {
        Self::from(&MixerState::default())
    }

    #[frb(sync)]
    pub fn new_with_param(
        channels: HashMap<u32, UiMixerChannel>,
        master_bus: UiMixerChannel,
        buses: HashMap<u32, UiBus>,
        routing: Vec<UiRoutingConnection>,
    ) -> Self {
        Self {
            channels,
            master_bus,
            buses,
            routing,
        }
    }
}

pub enum UiMixerChannelParams {
    Volume(f32),
    Pan(f32),
    Mute(bool),
    InvertedPhase(bool),
    Solo(bool),
}

impl From<&MixerChannelParams> for UiMixerChannelParams {
    fn from(params: &MixerChannelParams) -> Self {
        match params {
            MixerChannelParams::Volume(value) => Self::Volume(*value),
            MixerChannelParams::Pan(value) => Self::Pan(*value),
            MixerChannelParams::Mute(value) => Self::Mute(*value),
            MixerChannelParams::InvertedPhase(value) => Self::InvertedPhase(*value),
            MixerChannelParams::Solo(value) => Self::Solo(*value),
        }
    }
}

impl From<&UiMixerChannelParams> for MixerChannelParams {
    fn from(params: &UiMixerChannelParams) -> Self {
        match params {
            // Volume is in dB (both UI and backend use dB)
            UiMixerChannelParams::Volume(value) => Self::Volume(*value),
            UiMixerChannelParams::Pan(value) => Self::Pan(*value),
            UiMixerChannelParams::Mute(value) => Self::Mute(*value),
            UiMixerChannelParams::InvertedPhase(value) => Self::InvertedPhase(*value),
            UiMixerChannelParams::Solo(value) => Self::Solo(*value),
        }
    }
}

#[derive(Clone, Debug)]
pub enum ParameterValueTypeDTO {
    Float,
    Int,
    Bool,
    Choice,
}

// 2. Mirror the Struct
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct ParameterSpecDTO {
    pub id: u32,
    pub name: String,
    pub group: String,
    pub value: f32,
    pub min: f32,
    pub max: f32,
    pub default_value: f32,
    pub step: f32,
    pub value_type: ParameterValueTypeDTO,
    pub choices: Vec<String>,
}

impl From<ParameterValueType> for ParameterValueTypeDTO {
    fn from(val: ParameterValueType) -> Self {
        match val {
            ParameterValueType::Float => ParameterValueTypeDTO::Float,
            ParameterValueType::Int => ParameterValueTypeDTO::Int,
            ParameterValueType::Bool => ParameterValueTypeDTO::Bool,
            ParameterValueType::Choice => ParameterValueTypeDTO::Choice,
        }
    }
}

impl From<&ParameterSpec> for ParameterSpecDTO {
    fn from(spec: &ParameterSpec) -> Self {
        Self {
            id: spec.id,
            name: spec.name.clone(),
            group: spec.group.clone(),
            value: spec.value as f32,
            min: spec.min as f32,
            max: spec.max as f32,
            default_value: spec.default_value as f32,
            step: spec.step as f32,
            value_type: spec.value_type.into(), // Automatically uses the enum mapping above
            choices: spec.choices.clone(),
        }
    }
}

// ======================================
// SETTERS — Command-Based (no AppState write)
// ======================================

/// Set a single DSP parameter on a mixer channel.
/// Routes through the audio thread ring buffer; AppState is only updated on save.
pub fn set_mixer_channel_param(
    ctx: &mut DawContext,
    target: UiMixerChannelTarget,
    param: UiMixerChannelParams,
) {
    let core_target = MixerChannelTarget::from(&target);
    let core_param = MixerChannelParams::from(&param);
    mixer_api::set_mixer_channel_param(ctx, core_target, core_param);
}

/// Request a full snapshot of a mixer channel's current DSP state.
/// The response arrives asynchronously as `UiAudioFeedback::MixerChannelSnapshot`
/// via the unified `create_feedback_stream` in `audio.rs`.
pub fn query_mixer_channel(ctx: &mut DawContext, target: UiMixerChannelTarget) {
    mixer_api::query_mixer_channel(ctx, MixerChannelTarget::from(&target));
}

// ======================================
// GETTERS
// ======================================

/// **GETTER: Fetch the mixer state**
pub fn get_mixer_state(ctx: &DawContext) -> UiMixerState {
    mixer_api::get_mixer_state(ctx, |mixer_state| UiMixerState::from(mixer_state))
}

/// **GETTER: Fetch a specific mixer channel**
pub fn get_mixer_channel(ctx: &DawContext, track_id: u32) -> Result<UiMixerChannel, String> {
    mixer_api::get_mixer_channel(ctx, TrackId::from(track_id), |mixer_channel| {
        UiMixerChannel::from(mixer_channel)
    })
    .map_err(|e| e.to_string())
}

pub fn get_mixer_channel_populated(
    ctx: &DawContext,
    track_id: u32,
) -> Result<(UiMixerChannel, Vec<UiEffectInstance>), String> {
    mixer_api::get_mixer_channel_populated(
        ctx,
        TrackId::from(track_id),
        |channel| UiMixerChannel::from(channel),
        |effect| UiEffectInstance::from(effect),
    )
    .map_err(|e| e.to_string())
}

/// **GETTER: Fetch the master bus**
pub fn get_master_bus(ctx: &DawContext) -> UiMixerChannel {
    mixer_api::get_master_bus(ctx).into()
}

pub fn get_master_bus_populated(ctx: &DawContext) -> Vec<UiEffectInstance> {
    mixer_api::get_master_bus_populated(ctx, |e| UiEffectInstance::from(e))
}

/// **GETTER: Fetch all buses**
pub fn get_buses(ctx: &DawContext) -> HashMap<u32, UiBus> {
    mixer_api::get_buses(ctx, |id, bus| (id.to_u32(), UiBus::from(bus)))
}

/// **GETTER: Fetch the routing matrix**
pub fn get_routing_matrix(ctx: &DawContext) -> Vec<UiRoutingConnection> {
    mixer_api::get_routing_matrix(ctx, |conn| UiRoutingConnection::from(conn))
}

/// Get track channel's parameter specs
pub fn get_track_mixer_channel_specs(
    ctx: &DawContext,
    track_id: u32,
) -> Option<Vec<ParameterSpecDTO>> {
    mixer_api::get_track_mixer_channel_specs(ctx, &TrackId::from(track_id), |param_spec| {
        ParameterSpecDTO::from(param_spec)
    })
}

/// Get bus channel's parameter specs
pub fn get_bus_mixer_channel_specs(ctx: &DawContext, bus_id: u32) -> Option<Vec<ParameterSpecDTO>> {
    mixer_api::get_bus_mixer_channel_specs(ctx, &BusId::from(bus_id), |param_spec| {
        ParameterSpecDTO::from(param_spec)
    })
}

/// get master channel's parameter specs
pub fn get_master_channel_specs(ctx: &DawContext) -> Vec<ParameterSpecDTO> {
    mixer_api::get_master_channel_specs(ctx, |param_spec| ParameterSpecDTO::from(param_spec))
}

// ======================================
// Effect Chain (structural — AppState backed)
// ======================================

/// Add an effect to a mixer channel by its registry ID (preferred method).
pub fn add_effect_to_mixer_channel_by_id(
    ctx: &mut DawContext,
    track_id: u32,
    registry_id: u32,
) -> Result<(), String> {
    mixer_api::add_effect_to_mixer_channel_by_id(ctx, TrackId::from(track_id), registry_id)
        .map_err(|e| e.to_string())?;
    log::info!(
        "Added effect with registry ID {} to track {}",
        registry_id,
        track_id
    );
    Ok(())
}

pub fn remove_effect_from_mixer_channel(
    ctx: &mut DawContext,
    track_id: u32,
    effect_instance_id: u32,
) -> Result<(), String> {
    mixer_api::remove_effect_from_mixer_channel(
        ctx,
        TrackId::from(track_id),
        EffectId::from(effect_instance_id),
    )
    .map_err(|e| e.to_string())?;
    log::info!(
        "Removed effect instance ID {} from track {}",
        effect_instance_id,
        track_id
    );
    Ok(())
}

pub fn add_effect_to_master_bus(ctx: &mut DawContext, registry_id: u32) -> Result<(), String> {
    mixer_api::add_effect_to_master_bus(ctx, registry_id).map_err(|e| e.to_string())?;
    log::info!(
        "Added effect with registry ID {} to master bus",
        registry_id
    );
    Ok(())
}

pub fn remove_effect_from_master_bus(
    ctx: &mut DawContext,
    effect_instance_id: u32,
) -> Result<(), String> {
    mixer_api::remove_effect_from_master_bus(ctx, EffectId::from(effect_instance_id))
        .map_err(|e| e.to_string())?;
    log::info!(
        "Removed effect instance ID {} from master bus",
        effect_instance_id
    );
    Ok(())
}

// ======================================
// BUS MANAGEMENT APIs
// ======================================

/// Create a new mixer bus and return its ID.
pub fn create_bus(ctx: &mut DawContext, name: String) -> Result<u32, String> {
    // TODO: Refactor this to Core's API
    let bus_id = mixer_api::create_bus(ctx, name);
    Ok(bus_id.into())
}

/// Delete a mixer bus.
pub fn delete_bus(ctx: &mut DawContext, bus_id: u32) -> Result<(), String> {
    mixer_api::delete_bus(ctx, BusId::from(bus_id)).map_err(|e| e.to_string())
}

// ======================================
// BUS EFFECT MANAGEMENT APIs
// ======================================

/// Add an effect to a bus by its registry ID.
pub fn add_effect_to_bus(
    ctx: &mut DawContext,
    bus_id: u32,
    registry_id: u32,
) -> Result<(), String> {
    mixer_api::add_effect_to_bus(ctx, BusId::from(bus_id), registry_id)
        .map_err(|e| e.to_string())?;
    log::info!(
        "Added effect with registry ID {} to bus {}",
        registry_id,
        bus_id
    );
    Ok(())
}

pub fn rename_bus(ctx: &mut DawContext, bus_id: u32, new_name: String) -> Result<(), String> {
    mixer_api::rename_bus(ctx, BusId::from(bus_id), &new_name).map_err(|e| e.to_string())
}

// ======================================
// ROUTING APIs
// ======================================

pub fn get_channel_destinations(
    ctx: &DawContext,
    is_bus: bool,
    channel_id: u32,
) -> Vec<UiRoutingConnection> {
    let source_node = if is_bus {
        RoutingNode::Bus(BusId::from(channel_id))
    } else {
        RoutingNode::Track(TrackId::from(channel_id))
    };

    mixer_api::get_destinations_of_mixer_channel(ctx, &source_node, |conn| UiRoutingConnection {
        destination: UiRoutingNode::from(&conn.destination),
        send_level: conn.send_level,
        source: UiRoutingNode::from(&source_node),
        is_send: conn.is_send,
    })
}

/// Set routing: source → destination with send level.
pub fn set_routing(
    ctx: &mut DawContext,
    source: UiRoutingNode,
    destination: UiRoutingNode,
    send_level: f32,
    is_send: bool,
) -> Result<(), String> {
    let conn = RoutingConnection {
        source: source.into(),
        destination: destination.into(),
        send_level,
        is_send,
    };

    mixer_api::set_routing(ctx, conn).map_err(|e| e.to_string())
}

/// Remove a routing connection.
pub fn remove_routing(
    ctx: &mut DawContext,
    source: UiRoutingNode,
    destination: UiRoutingNode,
    is_send: bool,
) -> Result<(), String> {
    mixer_api::remove_routing(ctx, source.into(), destination.into(), is_send)
        .map_err(|e| e.to_string())
}

pub fn update_routing(ctx: &mut DawContext, conn: UiRoutingConnection) -> Result<(), String> {
    mixer_api::update_routing(ctx, conn.into()).map_err(|e| e.to_string())
}

/// Get the mixer snapshot telemetry. this uses a triple buffer last snapshot
#[frb(sync)]
pub fn get_mixer_telemetry_sync(ctx: &mut DawContext) -> MixerTelemetrySnapshotDto {
    mixer_api::get_mixer_telemetry_sync(ctx).into()
}

pub fn set_mixer_telemetry_subs(ctx: &mut DawContext, active: bool) -> Result<(), String> {
    mixer_api::set_mixer_telemetry_subs(ctx, active).map_err(|e| e.to_string())
}

// ======================================
// Sidechain-related API
// ======================================

/// Get all track channels and bus channels, and also
/// its current sidechain properties
pub fn get_sidechain_sources(
    ctx: &DawContext,
    sidechain_plugin: UiPluginTarget,
) -> Vec<UiSidechainSource> {
    mixer_api::get_sidechain_sources(ctx, sidechain_plugin.into())
        .into_iter()
        .map(|source| UiSidechainSource {
            source: UiRoutingNode::from(&source.source),
            name: source.name,
            enabled: source.send_level.is_some(),
            send_level: source.send_level.unwrap_or(1.0) as f64,
        })
        .collect()
}

/// Add/update a sidechain send when `send_level` is provided, or remove it
/// when `send_level` is null.
pub fn set_sidechain_source(
    ctx: &mut DawContext,
    plugin: UiPluginTarget,
    from: UiRoutingNode,
    send_level: Option<f64>,
) -> Result<(), String> {
    mixer_api::set_sidechain_source(
        ctx,
        plugin.into(),
        from.into(),
        send_level.map(|level| level as f32),
    )
    .map_err(|e| e.to_string())
}
