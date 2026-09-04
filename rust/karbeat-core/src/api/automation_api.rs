use anyhow::Context;
use karbeat_utils::types::{BipolarF64, NormalizedF64};

use crate::{
    commands::AudioCommand,
    context::DawContext,
    core::project::{
        AutomationCurveType, ModulationLink, ModulationLinkForOrderedLaneView, ModulationSource,
        automation::{AutomationLane, AutomationTarget},
    },
    shared::{AutomationId, BusId, ModulationId, ModulationLinkId, TrackId},
};

/// Get all automations lane for all types
pub fn get_automations_lanes_all<C, U, M>(ctx: &DawContext, mapper: M) -> C
where
    M: Fn(&AutomationLane) -> U,
    C: FromIterator<U>,
{
    let app = &ctx.app_state;

    app.automation_pool.values().map(|a| mapper(a)).collect()
}

pub fn add_automation_lane_for_track(
    ctx: &mut DawContext,
    track_id: TrackId,
    target: AutomationTarget,
    label: impl Into<String>,
    min: f64,
    max: f64,
    initial_value: f64,
) -> anyhow::Result<AutomationLane> {
    let app = &mut ctx.app_state;
    let (lane, link_id) =
        app.add_automation_lane_for_track(track_id, target, label, min, max, initial_value)?;

    broadcast_modulation(ctx, link_id)?;

    // Broadcast the new lane to the audio thread by its AutomationId
    ctx.broadcast_automation_lane(lane.id, &lane);

    // TODO: add history

    Ok(lane)
}

pub fn add_automation_lane(
    ctx: &mut DawContext,
    target: AutomationTarget,
    label: impl Into<String>,
    min: f64,
    max: f64,
    initial_value: f64,
) -> anyhow::Result<(AutomationLane, ModulationLinkForOrderedLaneView)> {
    let app = &mut ctx.app_state;
    let (lane, link_id) = app.add_automation_lane(target, label, min, max, initial_value)?;

    broadcast_modulation(ctx, link_id)?;

    ctx.broadcast_automation_lane(lane.id, &lane);

    // Fetch the modulation link
    let mod_link = ctx
        .app_state
        .modulation_links
        .get(link_id)
        .with_context(|| "Modulation link not found")?;
    // TODO: add history

    Ok((lane, mod_link.clone()))
}

pub fn add_automation_lane_for_bus(
    ctx: &mut DawContext,
    bus_id: BusId,
    target: AutomationTarget,
    label: impl Into<String>,
    min: f64,
    max: f64,
    initial_value: f64,
) -> anyhow::Result<AutomationLane> {
    let (lane, link_id) = {
        let app = &mut ctx.app_state;
        app.add_automation_lane_for_bus(bus_id, target, label, min, max, initial_value)?
    };

    broadcast_modulation(ctx, link_id)?;

    ctx.broadcast_automation_lane(lane.id, &lane);

    // TODO: add history

    Ok(lane)
}

pub fn remove_automation_lane(
    ctx: &mut DawContext,
    target: AutomationTarget,
) -> anyhow::Result<(AutomationId, Vec<ModulationId>, Vec<ModulationLinkId>)> {
    let app = &mut ctx.app_state;

    let (removed_lane, removed_sources, removed_links) = app
        .remove_automation_lane(target)
        .ok_or_else(|| anyhow::anyhow!("No automation lane found for this target"))?;

    let mut commands = Vec::new();

    // Safest DSP tear-down order: Unplug Cable (Link) -> Destroy Generator (Source) -> Destroy Lane
    for link_id in removed_links.iter() {
        commands.push(AudioCommand::RemoveModulationLink(*link_id));
    }

    for source_id in removed_sources.iter() {
        commands.push(AudioCommand::RemoveModulationSource(*source_id));
    }
    commands.push(AudioCommand::RemoveAutomationLane { id: removed_lane });

    if !commands.is_empty() {
        ctx.try_send_audio_command_chain(commands)?;
    }

    Ok((
        removed_lane,
        removed_sources.into_iter().collect(),
        removed_links.into_iter().collect(),
    ))
}

pub fn add_new_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    time_ticks: u32,
    value: NormalizedF64,
) -> anyhow::Result<(AutomationLane, u64)> {
    let app = &mut ctx.app_state;
    let (auto_lane, point_id) = app.add_automation_point(automation_id, time_ticks, value)?;

    ctx.broadcast_automation_lane(automation_id, &auto_lane);

    // TODO: Add history
    Ok((auto_lane, point_id))
}

pub fn remove_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    id: u64,
) -> anyhow::Result<AutomationLane> {
    let app = &mut ctx.app_state;
    let lane = app.remove_automation_point(automation_id, id)?;

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(lane)
}

pub fn update_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    id: u64,
    time_ticks: Option<u32>,
    value: Option<NormalizedF64>,
    tension: Option<BipolarF64>,
    curve_type: Option<AutomationCurveType>,
) -> anyhow::Result<usize> {
    let app = &mut ctx.app_state;

    let (lane, new_index) =
        app.update_automation_point(automation_id, id, time_ticks, value, tension, curve_type)?;

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(new_index)
}

pub fn get_automation_lanes_for_track(
    ctx: &DawContext,
    track_id: TrackId,
) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
    let app = &ctx.app_state;
    app.get_automation_lanes_for_track(track_id)
}

pub fn get_automation_lanes_for_bus(
    ctx: &DawContext,
    bus_id: BusId,
) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
    let app = &ctx.app_state;
    app.get_automation_lanes_for_bus(bus_id)
}

pub fn get_automation_lane<Id: Into<AutomationId>>(
    ctx: &DawContext,
    lane_id: Id,
) -> Option<AutomationLane> {
    let app = &ctx.app_state;
    let id_typed = lane_id.into();
    app.automation_pool.get(id_typed).cloned()
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Modulation API
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Get all modulations in the project
pub fn get_all_linked_modulation_params<Id, T, F>(
    ctx: &DawContext,
    f: F,
) -> std::collections::HashMap<Id, T>
where
    Id: std::hash::Hash + std::cmp::Eq,
    F: Fn(&ModulationLinkId, &crate::core::project::ModulationLinkForOrderedLaneView) -> (Id, T),
{
    let app = &ctx.app_state;
    app.modulation_links
        .iter()
        .map(|(id, modulation)| f(&id, modulation))
        .collect()
}

pub fn get_modulation_link_by_id<Id>(
    ctx: &DawContext,
    id: Id,
) -> Option<ModulationLinkForOrderedLaneView>
where
    Id: Into<ModulationLinkId>,
{
    let app = &ctx.app_state;
    let id_typed = id.into();
    app.modulation_links.get(id_typed).cloned()
}

/// Add generic modulation source
pub fn add_modulation_source(ctx: &mut DawContext, source: ModulationSource) -> ModulationId {
    let id = {
        let app = &mut ctx.app_state;
        app.add_modulation_source(source.clone())
    };

    let _ = ctx.send_audio_command(AudioCommand::AddModulationSource { id, source });
    id
}

pub fn get_modulation_sources_map<Id, S, C>(ctx: &DawContext) -> C
where
    Id: From<ModulationId>,
    S: for<'a> From<&'a ModulationSource>,
    C: FromIterator<(Id, S)>,
{
    let app = &ctx.app_state;
    app.modulation_sources
        .iter()
        .map(|(id, s)| (Id::from(id), S::from(s)))
        .collect::<C>()
}

/// Get modulation source based on its modulation id
pub fn get_modulation_source<'a, Id, Siuuuu>(
    ctx: &'a DawContext,
    modulation_id: Id,
) -> Option<Siuuuu>
where
    Id: Into<ModulationId>,
    Siuuuu: From<&'a ModulationSource>,
{
    let app = &ctx.app_state;
    let id_typed = modulation_id.into();
    app.modulation_sources
        .get(id_typed)
        .map(|s| Siuuuu::from(s))
}

/// Remove the modulation source. This function also cascade delete all link
/// with this source
pub fn remove_modulation_source(ctx: &mut DawContext, mod_id: ModulationId) {
    {
        let app = &mut ctx.app_state;
        let _ = app.remove_modulation_source(mod_id);
    }
    let _ = ctx.send_audio_command(AudioCommand::RemoveModulationSource(mod_id));
}

pub fn remove_modulation_link(ctx: &mut DawContext, mod_link_id: ModulationLinkId) {
    {
        let app = &mut ctx.app_state;
        let _ = app.remove_modulation_link(mod_link_id);
    }

    let _ = ctx.send_audio_command(AudioCommand::RemoveModulationLink(mod_link_id));
}

/// Link the target param to a modulation source
pub fn link_this_param_to_controller(
    ctx: &mut DawContext,
    source_id: ModulationId,
    target: AutomationTarget,
    depth: f32,
    base_value: f32,
) -> anyhow::Result<ModulationLinkId> {
    let (id, link) = {
        let app = &mut ctx.app_state;
        let id = app.link_modulation(source_id, target, depth, base_value)?;
        let link = app
            .modulation_links
            .get(id)
            .map(|l| ModulationLink {
                id,
                source_id: l.prop.source_id,
                target: l.prop.target.clone(),
                depth: l.prop.depth,
                base_value: l.prop.base_value,
            })
            .ok_or_else(|| anyhow::anyhow!("Link not found after insertion"))?;
        (id, link)
    };

    let _ = ctx.send_audio_command(AudioCommand::AddModulationLink { id, link });
    Ok(id)
}

fn broadcast_modulation(ctx: &mut DawContext, link_id: ModulationLinkId) -> anyhow::Result<()> {
    let mut commands = Vec::new();

    if let Some(link) = ctx.app_state.modulation_links.get(link_id) {
        let source_id = link.prop.source_id;

        if let Some(source) = ctx.app_state.modulation_sources.get(source_id) {
            commands.push(AudioCommand::AddModulationSource {
                id: source_id,
                source: source.to_owned(),
            });
            commands.push(AudioCommand::AddModulationLink {
                id: link_id,
                link: link.prop.to_owned(),
            });
        } else {
            commands.push(AudioCommand::RemoveModulationSource(source_id));
            commands.push(AudioCommand::RemoveModulationLink(link_id));
        }
    } else {
        commands.push(AudioCommand::RemoveModulationLink(link_id));
    }

    // Dispatch the accumulated commands
    ctx.try_send_audio_command_chain(commands)
}
