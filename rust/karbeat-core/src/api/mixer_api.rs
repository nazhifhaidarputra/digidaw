use crate::{
    audio::{engine::MixerTelemetrySnapshot, event::PluginTarget},
    commands::{AudioCommand, EffectTarget, MixerChannelTarget},
    context::DawContext,
    core::project::{
        SidechainRoute, TrackId,
        mixer::{
            BusMixerChannel, EffectInstance, MixerChannel, MixerChannelParams, MixerState,
            RoutingConnection, RoutingNode,
        },
    },
    shared::id::*,
};
use anyhow::Context;
use karbeat_plugin_types::ParameterSpec;

#[derive(Clone, Debug)]
pub struct SidechainSource {
    pub source: RoutingNode,
    pub name: String,
    pub send_level: Option<f32>,
}

/// **GETTER: Fetch the mixer state from application state and map it to T value**
pub fn get_mixer_state<T, F>(ctx: &DawContext, mapper: F) -> T
where
    F: FnOnce(&MixerState) -> T,
{
    mapper(&ctx.app_state.mixer)
}

/// **GETTER: Get Specific Mixer Channel and map it to T value
pub fn get_mixer_channel<T, F>(ctx: &DawContext, track_id: TrackId, mapper: F) -> anyhow::Result<T>
where
    F: Fn(&MixerChannel) -> T,
{
    let mixer_state = &ctx.app_state.mixer;
    let channel = mixer_state.channels.get(track_id);
    channel
        .ok_or_else(|| anyhow::anyhow!("Channel not found"))
        .map(|c| mapper(&c.channel))
}

/// Get track channel's parameter specs
pub fn get_track_mixer_channel_specs<C, U, M>(
    ctx: &DawContext,
    track_id: &TrackId,
    mapper: M,
) -> Option<C>
where
    M: Fn(&ParameterSpec) -> U,
    C: FromIterator<U>,
{
    let mix_channel = &ctx.app_state.mixer.channels.get(*track_id)?;
    Some(
        mix_channel
            .channel
            .get_channel_specs()
            .iter()
            .map(mapper)
            .collect(),
    )
}

/// Get bus channel's parameter specs
pub fn get_bus_mixer_channel_specs<C, U, M>(
    ctx: &DawContext,
    bus_id: &BusId,
    mapper: M,
) -> Option<C>
where
    M: Fn(&ParameterSpec) -> U,
    C: FromIterator<U>,
{
    let bus_channel = &ctx.app_state.mixer.buses.get(*bus_id)?;
    Some(
        bus_channel
            .channel
            .get_channel_specs()
            .iter()
            .map(mapper)
            .collect(),
    )
}

/// get master channel's parameter specs
pub fn get_master_channel_specs<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&ParameterSpec) -> U,
    C: FromIterator<U>,
{
    ctx.app_state
        .mixer
        .master_bus
        .get_channel_specs()
        .iter()
        .map(mapper)
        .collect()
}

pub fn get_mixer_channel_populated<C, MC, EI, MixChanF, EffInstF>(
    ctx: &DawContext,
    track_id: TrackId,
    mixer_mapper: MixChanF,
    instance_mapper: EffInstF,
) -> anyhow::Result<(MC, C)>
where
    MixChanF: FnOnce(&MixerChannel) -> MC,
    EffInstF: Fn(&EffectInstance) -> EI,
    C: FromIterator<EI>,
{
    let channel = &ctx
        .app_state
        .mixer
        .channels
        .get(track_id)
        .ok_or_else(|| anyhow::anyhow!("Channel not found"))?;

    let mapped_channel = mixer_mapper(&channel.channel);

    let mapped_effects: C = channel
        .channel
        .effects
        .iter()
        .map(|e| instance_mapper(e))
        .collect();

    Ok((mapped_channel, mapped_effects))
}

pub fn get_master_bus(ctx: &DawContext) -> &MixerChannel {
    &ctx.app_state.mixer.master_bus
}

pub fn get_master_bus_populated<C, T, F>(ctx: &DawContext, mapper: F) -> C
where
    F: Fn(&EffectInstance) -> T,
    C: FromIterator<T>,
{
    ctx.app_state
        .mixer
        .master_bus
        .effects
        .iter()
        .map(|e| mapper(e))
        .collect::<C>()
}

/// **GETTER: Fetch all buses**
pub fn get_buses<C, T, F>(ctx: &DawContext, mut mapper: F) -> C
where
    F: FnMut(&BusId, &BusMixerChannel) -> T,
    C: FromIterator<T>,
{
    ctx.app_state
        .mixer
        .buses
        .iter()
        .map(|(id, bus)| mapper(&id, bus))
        .collect()
}

/// **GETTER: Fetch the routing matrix**
pub fn get_routing_matrix<C, T, F>(ctx: &DawContext, mut mapper: F) -> C
where
    F: FnMut(&RoutingConnection) -> T,
    C: FromIterator<T>,
{
    ctx.app_state
        .mixer
        .routing
        .iter()
        .map(|conn| mapper(conn))
        .collect()
}

/// **GETTER: Fetch the routing destinations for a specific source channel**
pub fn get_destinations_of_mixer_channel<C, T, F>(
    ctx: &DawContext,
    source: &RoutingNode,
    mut mapper: F,
) -> C
where
    F: FnMut(&RoutingConnection) -> T,
    C: FromIterator<T>,
{
    ctx.app_state
        .mixer
        .routing
        .iter()
        .filter(|conn| conn.source == *source)
        .map(|conn| mapper(conn))
        .collect()
}

// ======================================
// Mixer Channel DSP Parameter Commands
// ======================================

/// Push a single DSP parameter change for a mixer channel into the audio thread
/// via the ring buffer. The audio thread is the sole owner of these values;
/// AppState is only updated during save_project.
pub fn set_mixer_channel_param(
    ctx: &mut DawContext,
    target: MixerChannelTarget,
    param: MixerChannelParams,
) {
    let _ = ctx.send_audio_command(AudioCommand::SetMixerChannelParameter { target, param });
}

/// Ask the audio thread to emit a full MixerChannelSnapshot for the given
/// channel. Poll the result with `poll_mixer_channel_feedback`.
pub fn query_mixer_channel(ctx: &mut DawContext, target: MixerChannelTarget) {
    let _ = ctx.send_audio_command(AudioCommand::QueryMixerChannel { target });
}

// ======================================
// Effect Chain (structural, still AppState-backed)
// ======================================

pub fn add_effect_to_mixer_channel_by_id(
    ctx: &mut DawContext,
    track_id: TrackId,
    registry_id: u32,
) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    app.mixer
        .add_effect_descriptor_by_id(&mut ctx.plugin_registry, &track_id, registry_id)?;
    let effect_id = app
        .mixer
        .channels
        .get(track_id)
        .and_then(|ch| ch.channel.effects.last())
        .map(|e| e.id)
        .ok_or_else(|| anyhow::anyhow!("Effect not found after insertion"))?;

    if let Some(plugin) = ctx.get_plugin_box(registry_id) {
        let _ = ctx.send_audio_command(AudioCommand::AddEffect {
            target: EffectTarget::Track(track_id),
            effect_id,
            effect: plugin,
        });
    } else {
        log::warn!(
            "[mixer_api] Could not instantiate effect plugin {:?} for audio thread",
            registry_id
        );
    }
    Ok(())
}

pub fn remove_effect_from_mixer_channel(
    ctx: &mut DawContext,
    track_id: TrackId,
    effect_instance_id: EffectId,
) -> anyhow::Result<()> {
    ctx.app_state
        .mixer
        .remove_effect_by_id(&track_id, effect_instance_id)?;
    let _ = ctx.send_audio_command(AudioCommand::RemoveEffect {
        target: EffectTarget::Track(track_id),
        effect_id: effect_instance_id,
    });
    Ok(())
}

pub fn add_effect_to_master_bus(ctx: &mut DawContext, registry_id: u32) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    app.mixer
        .add_effect_to_master_bus(&mut ctx.plugin_registry, registry_id)?;
    let effect_id = app
        .mixer
        .master_bus
        .effects
        .last()
        .map(|e| e.id)
        .ok_or_else(|| anyhow::anyhow!("Effect not found after insertion"))?;

    if let Some(plugin) = ctx.get_plugin_box(registry_id) {
        let _ = ctx.send_audio_command(AudioCommand::AddEffect {
            target: EffectTarget::Master,
            effect_id,
            effect: plugin,
        });
    } else {
        log::warn!(
            "[mixer_api] Could not instantiate master effect plugin {:?}",
            registry_id
        );
    }
    Ok(())
}

pub fn move_effect_order(
    ctx: &mut DawContext,
    mixer_channel_target: MixerChannelTarget,
    effect_id: EffectId,
    new_position: usize,
) -> anyhow::Result<()> {
    let effect_target = effect_target_from_mixer_target(&mixer_channel_target);
    ctx.app_state
        .get_mixer_channel_from_target_mut(mixer_channel_target)
        .with_context(|| "Cannot find the target mixer channel")?
        .move_and_shift_effect_chain(effect_id, new_position)?;
    let _ = ctx.send_audio_command(AudioCommand::MoveEffect {
        target: effect_target,
        effect_id,
        new_position,
    });
    Ok(())
}

pub fn remove_effect_from_target_mixer_channel(
    ctx: &mut DawContext,
    mixer_channel_target: MixerChannelTarget,
    effect_instance_id: EffectId,
) -> anyhow::Result<()> {
    let effect_target = effect_target_from_mixer_target(&mixer_channel_target);
    match mixer_channel_target {
        MixerChannelTarget::Track(track_id) => {
            ctx.app_state
                .mixer
                .remove_effect_by_id(&track_id, effect_instance_id)?;
        }
        MixerChannelTarget::Bus(bus_id) => {
            ctx.app_state
                .mixer
                .remove_effect_from_bus(bus_id, effect_instance_id)?;
        }
        MixerChannelTarget::Master => {
            ctx.app_state
                .mixer
                .remove_effect_from_master_bus(effect_instance_id)?;
        }
    }
    let _ = ctx.send_audio_command(AudioCommand::RemoveEffect {
        target: effect_target,
        effect_id: effect_instance_id,
    });
    Ok(())
}

fn effect_target_from_mixer_target(target: &MixerChannelTarget) -> EffectTarget {
    match target {
        MixerChannelTarget::Track(track_id) => EffectTarget::Track(*track_id),
        MixerChannelTarget::Bus(bus_id) => EffectTarget::Bus(*bus_id),
        MixerChannelTarget::Master => EffectTarget::Master,
    }
}

pub fn remove_effect_from_master_bus(
    ctx: &mut DawContext,
    effect_instance_id: EffectId,
) -> anyhow::Result<()> {
    ctx.app_state
        .mixer
        .remove_effect_from_master_bus(effect_instance_id)?;
    let _ = ctx.send_audio_command(AudioCommand::RemoveEffect {
        target: EffectTarget::Master,
        effect_id: effect_instance_id,
    });
    Ok(())
}

pub fn create_bus(ctx: &mut DawContext, name: String) -> BusId {
    let bus_id = ctx.app_state.mixer.create_bus(name.clone());
    let _ = ctx.send_audio_command(AudioCommand::AddBus { bus_id, name });
    bus_id
}

pub fn delete_bus(ctx: &mut DawContext, bus_id: BusId) -> anyhow::Result<()> {
    ctx.app_state.mixer.remove_bus(bus_id)?;
    let _ = ctx.send_audio_command(AudioCommand::RemoveBus { bus_id });
    Ok(())
}

pub fn add_effect_to_bus(
    ctx: &mut DawContext,
    bus_id: BusId,
    registry_id: u32,
) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    app.mixer
        .add_effect_to_bus(&mut ctx.plugin_registry, bus_id, registry_id)?;
    let effect_id = app
        .mixer
        .buses
        .get(bus_id)
        .and_then(|b| b.channel.effects.last())
        .map(|e| e.id)
        .ok_or_else(|| anyhow::anyhow!("Effect not found after insertion"))?;

    if let Some(plugin) = ctx.get_plugin_box(registry_id) {
        let _ = ctx.send_audio_command(AudioCommand::AddEffect {
            target: EffectTarget::Bus(bus_id),
            effect_id,
            effect: plugin,
        });
    } else {
        log::warn!(
            "[mixer_api] Could not instantiate bus effect plugin {:?}",
            registry_id
        );
    }
    Ok(())
}

pub fn rename_bus(ctx: &mut DawContext, bus_id: BusId, new_name: &str) -> anyhow::Result<()> {
    ctx.app_state.mixer.rename_bus(bus_id, new_name)
}

pub fn set_routing(ctx: &mut DawContext, conn: RoutingConnection) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    app.mixer.add_routing(conn, &app.tracks)?;
    let routing = app.mixer.routing.clone().into_boxed_slice();
    let _ = ctx.send_audio_command(AudioCommand::UpdateRouting { routing });
    Ok(())
}

pub fn remove_routing(
    ctx: &mut DawContext,
    source: RoutingNode,
    destination: RoutingNode,
    is_send: bool,
) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    app.mixer.remove_routing(source, destination, is_send)?;
    let routing = app.mixer.routing.clone().into_boxed_slice();
    let _ = ctx.send_audio_command(AudioCommand::UpdateRouting { routing });
    Ok(())
}

pub fn update_routing(ctx: &mut DawContext, conn: RoutingConnection) -> anyhow::Result<()> {
    let app = &mut ctx.app_state;
    let routing = app.mixer.update_routing(conn, &app.tracks)?;
    let _ = ctx.send_audio_command(AudioCommand::UpdateRouting { routing });
    Ok(())
}

// ===========================================
// ======= Mixer shared pointer API ======
// ===========================================

pub fn get_mixer_telemetry_sync(ctx: &mut DawContext) -> MixerTelemetrySnapshot {
    // Drain any pending telemetry consumer registrations first, so plugin consumers
    // are up to date before anyone calls get_plugin_telemetry_sync.
    ctx.drain_telemetry_registrations();

    // triple_buffer::Output::read() requires &mut self but is lock-free and wait-free.
    // .clone() gives the caller an owned copy safe to pass across the FFI boundary.
    if let Some(reg) = ctx.telemetry_registry.as_mut() {
        reg.mixer_telemetry_consumer.update();
        reg.mixer_telemetry_consumer.read().clone()
    } else {
        MixerTelemetrySnapshot::default()
    }
}

pub fn set_mixer_telemetry_subs(ctx: &mut DawContext, active: bool) -> anyhow::Result<()> {
    ctx.send_audio_command(AudioCommand::SetMixerTelemetrySubscription { active })
}

// =================================================
// SIDECHAIN getter and updater
// =================================================

/// Get all track channels and bus channels, and also
/// its current sidechain properties
pub fn get_sidechain_sources(
    ctx: &DawContext,
    sidechain_plugin: PluginTarget,
) -> Vec<SidechainSource> {
    let sidechain_route = SidechainRoute::from(sidechain_plugin);
    let destination = RoutingNode::PluginSidechain(sidechain_route);
    let owner = sidechain_route.owner_node(&ctx.app_state.tracks);

    let mut available_sources = Vec::new();

    let get_existing_level = |source: RoutingNode| {
        ctx.app_state
            .mixer
            .routing
            .iter()
            .find(|connection| connection.source == source && connection.destination == destination)
            .map(|connection| connection.send_level)
    };

    let can_add_source = |source: RoutingNode| {
        let mut mixer = ctx.app_state.mixer.clone();
        mixer
            .add_routing(
                RoutingConnection::new_send(source, destination, 1.0),
                &ctx.app_state.tracks,
            )
            .is_ok()
    };

    for (track_id, track) in &ctx.app_state.tracks {
        let source = RoutingNode::Track(track_id);
        if owner == Some(source) {
            continue;
        }

        let send_level = get_existing_level(source);
        if send_level.is_some() || can_add_source(source) {
            available_sources.push(SidechainSource {
                source,
                name: track.name.clone(),
                send_level,
            });
        }
    }

    for (bus_id, bus) in &ctx.app_state.mixer.buses {
        let source = RoutingNode::Bus(bus_id);
        if owner == Some(source) {
            continue;
        }

        let send_level = get_existing_level(source);
        if send_level.is_some() || can_add_source(source) {
            available_sources.push(SidechainSource {
                source,
                name: bus.name.clone(),
                send_level,
            });
        }
    }

    available_sources.sort_by(|a, b| a.name.cmp(&b.name));
    available_sources
}

/// Add/update a sidechain send when `send_level` is `Some`, or remove it when
/// `send_level` is `None`.
pub fn set_sidechain_source(
    ctx: &mut DawContext,
    this_plugin: PluginTarget,
    from: RoutingNode,
    send_level: Option<f32>,
) -> anyhow::Result<()> {
    let sidechain_route = SidechainRoute::from(this_plugin);
    let routing_node_dest = RoutingNode::PluginSidechain(sidechain_route);

    if sidechain_route.owner_node(&ctx.app_state.tracks) == Some(from) {
        return Err(anyhow::anyhow!(
            "A plugin cannot use its own mixer channel as a sidechain source"
        ));
    }
    if matches!(from, RoutingNode::Master | RoutingNode::PluginSidechain(_)) {
        return Err(anyhow::anyhow!("Invalid sidechain source"));
    }

    match send_level {
        Some(level) => {
            let connection =
                RoutingConnection::new_send(from, routing_node_dest, level.clamp(0.0, 1.0));
            ctx.app_state
                .mixer
                .update_routing(connection, &ctx.app_state.tracks)?;
        }
        None => {
            let exists = ctx.app_state.mixer.routing.iter().any(|connection| {
                connection.source == from
                    && connection.destination == routing_node_dest
                    && connection.is_send
            });
            if exists {
                ctx.app_state
                    .mixer
                    .remove_routing(from, routing_node_dest, true)?;
            }
        }
    }

    let routings = ctx.app_state.mixer.routing.clone().into_boxed_slice();
    let _ = ctx.send_audio_command(AudioCommand::UpdateRouting { routing: routings });
    Ok(())
}
