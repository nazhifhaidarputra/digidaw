use anyhow::Context;
use karbeat_plugin_types::{ParameterSpec, ParameterValueType};
use karbeat_utils::types::{BipolarF64, NormalizedF64};

use karbeat_core::{
    audio::engine::AudioMixerChannelValues,
    commands::AudioCommand,
    context::DawContext,
    core::{
        history::actions::AutomationRecorder,
        project::{
            AutomationCurveType, AutomationPoint, BezierHandles, EffectAutomationTarget,
            MasterAutomationTarget, MixerChannel, MixerChannelParamTarget, ModulationLink,
            ModulationLinkForOrderedLaneView, ModulationSource, TEMPO_AUTOMATION_MAX_BPM,
            TEMPO_AUTOMATION_MIN_BPM, TrackAutomationTarget,
            automation::{AutomationLane, AutomationTarget},
        },
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

/// Creates an automation lane targeting a parameter on a track-owned mixer or plugin object.
pub fn add_automation_lane_for_track(
    ctx: &mut DawContext,
    track_id: TrackId,
    target: AutomationTarget,
    label: impl Into<String>,
    initial_value: Option<f64>,
) -> anyhow::Result<AutomationLane> {
    let initial_value = initial_normalized_value(ctx, &target, initial_value)?;
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;
    let (lane, link_id) =
        app.add_automation_lane_for_track(track_id, target, label, initial_value)?;
    record(ctx, automation_before, "Add Automation Lane");

    broadcast_modulation(ctx, link_id)?;

    // Broadcast the new lane to the audio thread by its AutomationId
    ctx.broadcast_automation_lane(lane.id, &lane);

    // TODO: add history

    Ok(lane)
}

/// Inserts an automation lane for `target` and broadcasts it to the audio thread.
///
/// `initial_value` is the parameter's current value in its own unit (dB, Hz, ...); the target
/// parameter normalizes it. `None` starts the lane on the value stored in the project.
pub fn add_automation_lane(
    ctx: &mut DawContext,
    target: AutomationTarget,
    label: impl Into<String>,
    initial_value: Option<f64>,
) -> anyhow::Result<(AutomationLane, ModulationLinkForOrderedLaneView)> {
    let initial_value = initial_normalized_value(ctx, &target, initial_value)?;
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;
    let (lane, link_id) = app.add_automation_lane(target, label, initial_value)?;
    record(ctx, automation_before, "Add Automation Lane");

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

/// Creates an automation lane targeting a bus mixer or bus-effect parameter.
pub fn add_automation_lane_for_bus(
    ctx: &mut DawContext,
    bus_id: BusId,
    target: AutomationTarget,
    label: impl Into<String>,
    initial_value: Option<f64>,
) -> anyhow::Result<AutomationLane> {
    let initial_value = initial_normalized_value(ctx, &target, initial_value)?;
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let (lane, link_id) = {
        let app = &mut ctx.app_state;
        app.add_automation_lane_for_bus(bus_id, target, label, initial_value)?
    };
    record(ctx, automation_before, "Add Automation Lane");

    broadcast_modulation(ctx, link_id)?;

    ctx.broadcast_automation_lane(lane.id, &lane);

    // TODO: add history

    Ok(lane)
}

/// Removes an automation lane from project state and the audio-thread graph.
pub fn remove_automation_lane(
    ctx: &mut DawContext,
    target: AutomationTarget,
) -> anyhow::Result<(AutomationId, Vec<ModulationId>, Vec<ModulationLinkId>)> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;

    let (removed_lane, removed_sources, removed_links) = app
        .remove_automation_lane(target)
        .ok_or_else(|| anyhow::anyhow!("No automation lane found for this target"))?;
    record(ctx, automation_before, "Remove Automation Lane");

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

/// Updates whether an automation lane is linked into playback and republishes it.
pub fn set_automation_lane_enabled(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    enabled: bool,
) -> anyhow::Result<AutomationLane> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let lane = ctx
        .app_state
        .set_automation_lane_enabled(automation_id, enabled)?;
    record(ctx, automation_before, "Toggle Automation Lane");
    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(lane)
}

/// Adds a point to a lane and publishes the rebuilt lane to the audio thread.
pub fn add_new_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    time_ticks: u32,
    value: NormalizedF64,
) -> anyhow::Result<(AutomationLane, u64)> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;
    let (auto_lane, point_id) = app.add_automation_point(automation_id, time_ticks, value)?;
    record(ctx, automation_before, "Add Automation Point");

    ctx.broadcast_automation_lane(automation_id, &auto_lane);

    // TODO: Add history
    Ok((auto_lane, point_id))
}

/// Removes one point from a lane and republishes the lane snapshot.
pub fn remove_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    id: u64,
) -> anyhow::Result<AutomationLane> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;
    let lane = app.remove_automation_point(automation_id, id)?;
    record(ctx, automation_before, "Remove Automation Point");

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(lane)
}

/// Changes the supplied fields of an automation point and republishes the lane snapshot.
///
/// Returns the updated lane together with the point's index in it.
#[allow(
    clippy::too_many_arguments,
    reason = "each optional field is one independently editable point property"
)]
pub fn update_automation_point(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    id: u64,
    time_ticks: Option<u32>,
    value: Option<NormalizedF64>,
    tension: Option<BipolarF64>,
    curve_type: Option<AutomationCurveType>,
    handles: Option<BezierHandles>,
) -> anyhow::Result<(AutomationLane, usize)> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let app = &mut ctx.app_state;

    let (lane, new_index) = app.update_automation_point(
        automation_id,
        id,
        time_ticks,
        value,
        tension,
        curve_type,
        handles,
    )?;
    record(ctx, automation_before, "Edit Automation Point");

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok((lane, new_index))
}

/// Copies the curve of a lane between two ticks, with times relative to the range start.
pub fn copy_automation_range(
    ctx: &DawContext,
    automation_id: AutomationId,
    start_tick: u32,
    end_tick: u32,
) -> anyhow::Result<Vec<AutomationPoint>> {
    ctx.app_state
        .copy_automation_range(automation_id, start_tick, end_tick)
}

/// Removes every point of a lane between two ticks as one undo step.
pub fn delete_automation_range(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    start_tick: u32,
    end_tick: u32,
) -> anyhow::Result<AutomationLane> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let lane = ctx
        .app_state
        .delete_automation_range(automation_id, start_tick, end_tick)?;
    record(ctx, automation_before, "Delete Automation Range");

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(lane)
}

/// Pastes a copied curve into a lane as one undo step, replacing the points under it.
///
/// `length_ticks` is the length of the copied range and `target_length` optionally stretches the
/// curve to another length.
pub fn paste_automation_points(
    ctx: &mut DawContext,
    automation_id: AutomationId,
    at_tick: u32,
    points: &[AutomationPoint],
    length_ticks: u32,
    target_length: Option<u32>,
) -> anyhow::Result<AutomationLane> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let lane = ctx.app_state.paste_automation_points(
        automation_id,
        at_tick,
        points,
        length_ticks,
        target_length,
    )?;
    record(ctx, automation_before, "Paste Automation Curve");

    ctx.broadcast_automation_lane(automation_id, &lane);
    Ok(lane)
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Target parameter mapping
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Describes the parameter a target automates: its range, value type, and choice labels.
///
/// Automation lanes only hold normalized values, so this specification is the one place that
/// maps them to the parameter's own unit.
pub fn target_parameter_spec(
    ctx: &DawContext,
    target: &AutomationTarget,
) -> anyhow::Result<ParameterSpec> {
    let mixer = &ctx.app_state.mixer;
    let (channel, mix_target): (Option<&MixerChannel>, &MixerChannelParamTarget) = match target {
        AutomationTarget::Generator { param_id, .. } => {
            return plugin_parameter_spec(ctx, target, *param_id);
        }
        AutomationTarget::Master(MasterAutomationTarget::TempoBpm) => {
            let bpm = f64::from(ctx.app_state.transport.bpm);
            return Ok(ParameterSpec::new_float(
                0,
                "Tempo",
                "Transport",
                bpm,
                f64::from(TEMPO_AUTOMATION_MIN_BPM),
                f64::from(TEMPO_AUTOMATION_MAX_BPM),
                120.0,
                0.0,
            ));
        }
        AutomationTarget::Track {
            track_id,
            track_target: TrackAutomationTarget::MixerChannel(mix_target),
        } => (
            mixer.channels.get(*track_id).map(|c| &c.channel),
            mix_target,
        ),
        AutomationTarget::Bus { bus_id, mix_target } => {
            (mixer.buses.get(*bus_id).map(|b| &b.channel), mix_target)
        }
        AutomationTarget::Master(MasterAutomationTarget::MixerChannel(mix_target)) => {
            (Some(&mixer.master_bus), mix_target)
        }
    };

    // The engine's channel parameters own the range automation is played in; the project
    // channel supplies the value currently set by the user.
    let engine_channel = AudioMixerChannelValues::default();
    match mix_target {
        MixerChannelParamTarget::Volume => channel.map(|c| ParameterSpec {
            value: f64::from(c.volume.get_base()),
            ..engine_channel.volume.to_spec()
        }),
        MixerChannelParamTarget::Pan => channel.map(|c| ParameterSpec {
            value: f64::from(c.pan.get_base()),
            ..engine_channel.pan.to_spec()
        }),
        MixerChannelParamTarget::Plugin {
            target: EffectAutomationTarget::Mix,
            ..
        } => Some(ParameterSpec::new_float(
            0, "Mix", "Effect", 1.0, 0.0, 1.0, 1.0, 0.0,
        )),
        MixerChannelParamTarget::Plugin {
            target: EffectAutomationTarget::PluginParam { param_id },
            ..
        } => return plugin_parameter_spec(ctx, target, *param_id),
    }
    .ok_or_else(|| anyhow::anyhow!("Mixer channel for {target:?} not found"))
}

fn plugin_parameter_spec(
    ctx: &DawContext,
    target: &AutomationTarget,
    param_id: u32,
) -> anyhow::Result<ParameterSpec> {
    let plugin = target
        .as_plugin_target()
        .ok_or_else(|| anyhow::anyhow!("{target:?} is not a plugin parameter"))?;
    crate::plugin_api::get_plugin_parameter_specs(ctx, &plugin, |spec, _| spec)?
        .into_iter()
        .find(|spec| spec.id == param_id)
        .ok_or_else(|| anyhow::anyhow!("Parameter {param_id} not found for {target:?}"))
}

/// Normalizes the value a new lane starts on through the target parameter.
fn initial_normalized_value(
    ctx: &DawContext,
    target: &AutomationTarget,
    initial_value: Option<f64>,
) -> anyhow::Result<NormalizedF64> {
    let spec = target_parameter_spec(ctx, target)?;
    Ok(NormalizedF64::from_range(
        initial_value.unwrap_or(spec.value),
        spec.min,
        spec.max,
    ))
}

fn lane_parameter_spec(ctx: &DawContext, lane_id: AutomationId) -> anyhow::Result<ParameterSpec> {
    let target = ctx
        .app_state
        .automation_lane_target(lane_id)
        .ok_or_else(|| anyhow::anyhow!("Automation lane {lane_id:?} has no target"))?;
    target_parameter_spec(ctx, target)
}

/// Formats a lane's normalized value in the unit of the parameter it automates.
pub fn automation_value_text(
    ctx: &DawContext,
    lane_id: AutomationId,
    normalized: NormalizedF64,
) -> anyhow::Result<String> {
    Ok(parameter_value_text(
        &lane_parameter_spec(ctx, lane_id)?,
        normalized,
    ))
}

/// Parses text typed in the unit of a lane's parameter into a normalized lane value.
///
/// Accepts numbers for every parameter, choice labels for choice parameters, and `on` / `off`
/// for toggles. Values outside the parameter's range are clamped.
pub fn parse_automation_value(
    ctx: &DawContext,
    lane_id: AutomationId,
    text: &str,
) -> anyhow::Result<NormalizedF64> {
    let spec = lane_parameter_spec(ctx, lane_id)?;
    parse_parameter_value(&spec, text)
        .ok_or_else(|| anyhow::anyhow!("'{text}' is not a value of {}", spec.name))
}

fn parameter_value_text(spec: &ParameterSpec, normalized: NormalizedF64) -> String {
    let plain = normalized.to_range(spec.min, spec.max);
    match spec.value_type {
        ParameterValueType::Bool => if plain >= 0.5 { "On" } else { "Off" }.to_owned(),
        ParameterValueType::Choice => spec
            .choices
            .iter()
            .zip(0_u32..)
            .min_by(|(_, a), (_, b)| {
                (f64::from(*a) - plain)
                    .abs()
                    .total_cmp(&(f64::from(*b) - plain).abs())
            })
            .map_or_else(|| format!("{plain:.0}"), |(label, _)| label.clone()),
        ParameterValueType::Int => unsigned_zero(format!("{plain:.0}")),
        ParameterValueType::Float => unsigned_zero(format!("{plain:.2}")),
    }
}

/// Drops the minus sign from a value that rounds to zero, so it reads "0.00" and not "-0.00".
fn unsigned_zero(text: String) -> String {
    match text.strip_prefix('-') {
        Some(digits) if digits.chars().all(|c| c == '0' || c == '.') => digits.to_owned(),
        _ => text,
    }
}

fn parse_parameter_value(spec: &ParameterSpec, text: &str) -> Option<NormalizedF64> {
    let text = text.trim();
    let plain = match spec.value_type {
        ParameterValueType::Bool if text.eq_ignore_ascii_case("on") => Some(1.0),
        ParameterValueType::Bool if text.eq_ignore_ascii_case("off") => Some(0.0),
        ParameterValueType::Choice => spec
            .choices
            .iter()
            .zip(0_u32..)
            .find(|(label, _)| label.eq_ignore_ascii_case(text))
            .map(|(_, index)| f64::from(index)),
        _ => None,
    }
    .or_else(|| text.parse::<f64>().ok().filter(|value| value.is_finite()))?;
    Some(NormalizedF64::from_range(plain, spec.min, spec.max))
}

/// Returns cloned automation lanes whose targets belong to `track_id`.
pub fn get_automation_lanes_for_track(
    ctx: &DawContext,
    track_id: TrackId,
) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
    let app = &ctx.app_state;
    app.get_automation_lanes_for_track(track_id)
}

/// Returns cloned automation lanes whose targets belong to `bus_id`.
pub fn get_automation_lanes_for_bus(
    ctx: &DawContext,
    bus_id: BusId,
) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
    let app = &ctx.app_state;
    app.get_automation_lanes_for_bus(bus_id)
}

/// Returns one automation lane by identifier, or `None` when it is absent.
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
/// Maps every modulation link whose source matches the supplied modulation identifier.
pub fn get_all_linked_modulation_params<Id, T, F>(
    ctx: &DawContext,
    f: F,
) -> std::collections::HashMap<Id, T>
where
    Id: std::hash::Hash + std::cmp::Eq,
    F: Fn(
        &ModulationLinkId,
        &karbeat_core::core::project::ModulationLinkForOrderedLaneView,
    ) -> (Id, T),
{
    let app = &ctx.app_state;
    app.modulation_links
        .iter()
        .map(|(id, modulation)| f(&id, modulation))
        .collect()
}

/// Returns a modulation link by identifier without cloning unrelated project state.
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
/// Inserts a modulation source into project state and queues its audio-thread counterpart.
pub fn add_modulation_source(ctx: &mut DawContext, source: ModulationSource) -> ModulationId {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    let id = {
        let app = &mut ctx.app_state;
        app.add_modulation_source(source.clone())
    };
    record(ctx, automation_before, "Add Modulation Source");

    let _ = ctx.send_audio_command(AudioCommand::AddModulationSource { id, source });
    id
}

/// Maps all project modulation sources into a caller-selected collection.
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
/// Returns one borrowed modulation source by a caller-convertible identifier.
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
/// Removes a modulation source, its dependent links, and their audio-thread state.
pub fn remove_modulation_source(ctx: &mut DawContext, mod_id: ModulationId) {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    {
        let app = &mut ctx.app_state;
        let _ = app.remove_modulation_source(mod_id);
    }
    record(ctx, automation_before, "Remove Modulation Source");
    let _ = ctx.send_audio_command(AudioCommand::RemoveModulationSource(mod_id));
}

/// Removes one modulation link from project and audio-thread state.
pub fn remove_modulation_link(ctx: &mut DawContext, mod_link_id: ModulationLinkId) {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
    {
        let app = &mut ctx.app_state;
        let _ = app.remove_modulation_link(mod_link_id);
    }
    record(ctx, automation_before, "Remove Modulation Link");

    let _ = ctx.send_audio_command(AudioCommand::RemoveModulationLink(mod_link_id));
}

/// Link the target param to a modulation source
/// Creates a modulation link from a source to an automatable target parameter.
pub fn link_this_param_to_controller(
    ctx: &mut DawContext,
    source_id: ModulationId,
    target: AutomationTarget,
    depth: f32,
    base_value: f32,
) -> anyhow::Result<ModulationLinkId> {
    let automation_before = AutomationRecorder::begin(&ctx.app_state);
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
    record(ctx, automation_before, "Link Modulation");

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

/// Records what an automation edit changed as one undo step.
fn record(ctx: &mut DawContext, before: AutomationRecorder, label: &'static str) {
    let action = before.finish(&ctx.app_state, label);
    if !action.is_empty() {
        ctx.push_history(action);
    }
}
