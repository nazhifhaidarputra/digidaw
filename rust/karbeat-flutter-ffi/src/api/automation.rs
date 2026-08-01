use std::collections::HashMap;

use flutter_rust_bridge::frb;
use karbeat_core::{
    api::automation_api,
    context::DawContext,
    core::project::{
        AutomationCurveType, AutomationLane, AutomationPoint, AutomationTarget,
        EffectAutomationTarget, MasterAutomationTarget, MixerChannelParamTarget, ModulationLink,
        ModulationLinkForOrderedLaneView, ModulationSource, TrackAutomationTarget,
    },
    shared::{BusId, EffectId, TrackId},
};
use karbeat_utils::types::{BipolarF64, NormalizedF64};

use crate::api::plugin::UiPluginTarget;

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct AutomationLaneDto {
    pub id: u32,
    pub label: String,
    pub points: Vec<AutomationPointDto>,
    pub enabled: bool,
    pub min: f64,
    pub max: f64,
    pub default_value: f64,
}

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct AutomationPointDto {
    pub id: u64,
    pub time_ticks: u32,
    pub value: f64,
    pub curve_type: AutomationCurveTypeDto,
    pub tension: f64,
}

#[derive(Clone, Debug)]
pub enum AutomationTargetDto {
    Generator {
        generator_id: u32,
        param_id: u32,
    },
    Track {
        track_id: u32,
        track_target: TrackAutomationTargetDto,
    },
    Bus {
        bus_id: u32,
        mix_target: MixerChannelParamTargetDto,
    },
    Master(MasterAutomationTargetDto),
}

#[derive(Clone, Debug)]
pub enum MasterAutomationTargetDto {
    MixerChannel(MixerChannelParamTargetDto),
    TempoBpm,
}

#[derive(Clone, Debug)]
pub enum TrackAutomationTargetDto {
    MixerChannel(MixerChannelParamTargetDto),
}

#[derive(Clone, Debug)]
pub enum MixerChannelParamTargetDto {
    Volume,
    Pan,
    Plugin {
        effect_id: u32,
        target: EffectAutomationTargetDto,
    },
}

#[derive(Clone, Debug)]
pub enum EffectAutomationTargetDto {
    Mix,
    PluginParam { param_id: u32 },
}

#[derive(Clone, Debug)]
pub enum AutomationCurveTypeDto {
    Linear,
    Exponential,
    Step,
}

#[frb(dart_metadata=("freezed"))]
pub struct ModulationLinkDto {
    pub id: u32,
    pub source_id: u32,              // Which LFO/Macro is driving this?
    pub target: AutomationTargetDto, // What parameter is being turned?
    pub depth: f32,                  // How much is it turning? (-1.0 to 1.0)
    pub base_value: f32,
    pub order_idx: usize,
}

pub enum ModulationSourceDto {
    PeakController { source: UiPluginTarget },
    Automation { lane_id: u32 },
    Lfo { rate_hz: f32 },
}

impl From<&ModulationSource> for ModulationSourceDto {
    fn from(value: &ModulationSource) -> Self {
        match value {
            ModulationSource::PeakController { source } => Self::PeakController {
                source: source.into(),
            },
            ModulationSource::Automation { lane_id } => Self::Automation {
                lane_id: lane_id.to_u32(),
            },
            ModulationSource::LFO { rate_hz } => Self::Lfo { rate_hz: *rate_hz },
        }
    }
}

impl From<ModulationSourceDto> for ModulationSource {
    fn from(value: ModulationSourceDto) -> Self {
        match value {
            ModulationSourceDto::PeakController { source } => Self::PeakController {
                source: source.into(),
            },
            ModulationSourceDto::Automation { lane_id } => Self::Automation {
                lane_id: lane_id.into(),
            },
            ModulationSourceDto::Lfo { rate_hz } => Self::LFO { rate_hz },
        }
    }
}

impl From<&ModulationLinkForOrderedLaneView> for ModulationLinkDto {
    fn from(value: &ModulationLinkForOrderedLaneView) -> Self {
        Self {
            id: value.prop.id.into(),
            source_id: value.prop.source_id.into(),
            target: AutomationTargetDto::from(&value.prop.target),
            depth: value.prop.depth,
            base_value: value.prop.base_value,
            order_idx: value.order_idx,
        }
    }
}

impl From<ModulationLinkDto> for ModulationLinkForOrderedLaneView {
    fn from(value: ModulationLinkDto) -> Self {
        Self {
            order_idx: value.order_idx,
            prop: ModulationLink {
                id: value.id.into(),
                source_id: value.source_id.into(),
                target: value.target.into(),
                depth: value.depth,
                base_value: value.base_value,
            },
        }
    }
}

impl From<AutomationCurveType> for AutomationCurveTypeDto {
    fn from(curve: AutomationCurveType) -> Self {
        match curve {
            AutomationCurveType::Linear => Self::Linear,
            AutomationCurveType::Exponential => Self::Exponential,
            AutomationCurveType::Step => Self::Step,
        }
    }
}

impl From<AutomationCurveTypeDto> for AutomationCurveType {
    fn from(value: AutomationCurveTypeDto) -> Self {
        match value {
            AutomationCurveTypeDto::Linear => Self::Linear,
            AutomationCurveTypeDto::Exponential => Self::Exponential,
            AutomationCurveTypeDto::Step => Self::Step,
        }
    }
}

impl From<AutomationPointDto> for AutomationPoint {
    fn from(point: AutomationPointDto) -> Self {
        Self {
            id: point.id,
            time_ticks: point.time_ticks,
            value: NormalizedF64::new(point.value),
            curve_type: point.curve_type.into(),
            tension: BipolarF64::new(point.tension),
        }
    }
}

impl From<AutomationPoint> for AutomationPointDto {
    fn from(p: AutomationPoint) -> Self {
        Self {
            id: p.id,
            time_ticks: p.time_ticks,
            value: p.value.get(),
            curve_type: p.curve_type.into(),
            tension: p.tension.get(),
        }
    }
}

impl TryFrom<AutomationLaneDto> for AutomationLane {
    type Error = &'static str;

    fn try_from(l: AutomationLaneDto) -> Result<Self, Self::Error> {
        // If Flutter sends 1.5, this explicitly throws an Error
        let default_value = NormalizedF64::try_from(l.default_value)?;

        Ok(Self {
            id: l.id.into(),
            label: l.label,
            // (Assuming points also use TryFrom for their internal NormalizedF64 values)
            points: l
                .points
                .into_iter()
                .filter_map(|p| p.try_into().ok())
                .collect(),
            enabled: l.enabled,
            min: l.min,
            max: l.max,
            default_value,
        })
    }
}

impl From<&AutomationLane> for AutomationLaneDto {
    fn from(l: &AutomationLane) -> Self {
        Self {
            id: l.id.into(),
            label: l.label.clone(),
            points: l.points.iter().map(|p| p.to_owned().into()).collect(),
            enabled: l.enabled,
            min: l.min,
            max: l.max,
            default_value: l.default_value.get(),
        }
    }
}

impl From<&EffectAutomationTarget> for EffectAutomationTargetDto {
    fn from(target: &EffectAutomationTarget) -> Self {
        match target {
            EffectAutomationTarget::Mix => Self::Mix,
            EffectAutomationTarget::PluginParam { param_id } => Self::PluginParam {
                param_id: *param_id,
            },
        }
    }
}

impl From<&MixerChannelParamTarget> for MixerChannelParamTargetDto {
    fn from(target: &MixerChannelParamTarget) -> Self {
        match target {
            MixerChannelParamTarget::Volume => Self::Volume,
            MixerChannelParamTarget::Pan => Self::Pan,
            MixerChannelParamTarget::Plugin { effect_id, target } => Self::Plugin {
                effect_id: effect_id.to_u32(),
                target: EffectAutomationTargetDto::from(target),
            },
        }
    }
}

impl From<&TrackAutomationTarget> for TrackAutomationTargetDto {
    fn from(target: &TrackAutomationTarget) -> Self {
        match target {
            TrackAutomationTarget::MixerChannel(target) => {
                Self::MixerChannel(MixerChannelParamTargetDto::from(target))
            }
        }
    }
}

impl From<TrackAutomationTargetDto> for TrackAutomationTarget {
    fn from(dto: TrackAutomationTargetDto) -> Self {
        match dto {
            TrackAutomationTargetDto::MixerChannel(target) => {
                Self::MixerChannel(MixerChannelParamTarget::from(target))
            }
        }
    }
}

impl From<&AutomationTarget> for AutomationTargetDto {
    fn from(target: &AutomationTarget) -> Self {
        match target {
            AutomationTarget::Track {
                track_id,
                track_target,
            } => Self::Track {
                track_id: track_id.to_u32(),
                track_target: TrackAutomationTargetDto::from(track_target),
            },
            AutomationTarget::Bus { bus_id, mix_target } => Self::Bus {
                bus_id: bus_id.to_u32(),
                mix_target: MixerChannelParamTargetDto::from(mix_target),
            },
            AutomationTarget::Master(master_target) => {
                match master_target {
                    karbeat_core::core::project::MasterAutomationTarget::MixerChannel(
                        mix_target,
                    ) => Self::Master(MasterAutomationTargetDto::MixerChannel(
                        MixerChannelParamTargetDto::from(mix_target),
                    )),
                    karbeat_core::core::project::MasterAutomationTarget::TempoBpm => {
                        Self::Master(MasterAutomationTargetDto::TempoBpm)
                    }
                }

                // MixerChannelParamTargetDto::from(mix_target)
            }
            AutomationTarget::Generator {
                generator_id,
                param_id,
            } => Self::Generator {
                generator_id: (*generator_id).into(),
                param_id: *param_id,
            },
        }
    }
}

// ============================================================================
// CONVERSIONS: UI DTO -> Core Domain (Dart to Rust)
// ============================================================================

impl From<EffectAutomationTargetDto> for EffectAutomationTarget {
    fn from(dto: EffectAutomationTargetDto) -> Self {
        match dto {
            EffectAutomationTargetDto::Mix => Self::Mix,
            EffectAutomationTargetDto::PluginParam { param_id } => Self::PluginParam { param_id },
        }
    }
}

impl From<MixerChannelParamTargetDto> for MixerChannelParamTarget {
    fn from(dto: MixerChannelParamTargetDto) -> Self {
        match dto {
            MixerChannelParamTargetDto::Volume => Self::Volume,
            MixerChannelParamTargetDto::Pan => Self::Pan,
            MixerChannelParamTargetDto::Plugin { effect_id, target } => Self::Plugin {
                effect_id: EffectId::from(effect_id),
                target: EffectAutomationTarget::from(target),
            },
        }
    }
}

impl From<AutomationTargetDto> for AutomationTarget {
    fn from(dto: AutomationTargetDto) -> Self {
        match dto {
            AutomationTargetDto::Track {
                track_id,
                track_target,
            } => Self::Track {
                track_id: TrackId::from(track_id),
                track_target: TrackAutomationTarget::from(track_target),
            },
            AutomationTargetDto::Bus { bus_id, mix_target } => Self::Bus {
                bus_id: BusId::from(bus_id),
                mix_target: MixerChannelParamTarget::from(mix_target),
            },
            AutomationTargetDto::Master(master_target) => match master_target {
                MasterAutomationTargetDto::MixerChannel(mix_target) => Self::Master(
                    MasterAutomationTarget::MixerChannel(MixerChannelParamTarget::from(mix_target)),
                ),
                MasterAutomationTargetDto::TempoBpm => {
                    Self::Master(MasterAutomationTarget::TempoBpm)
                }
            },
            AutomationTargetDto::Generator {
                generator_id,
                param_id,
            } => Self::Generator {
                generator_id: generator_id.into(),
                param_id,
            },
        }
    }
}

/// Fetch the list of (modulation_id, automation_id, automation_lane) where
/// the target is the given track id
pub fn get_automation_lanes_for_track(
    ctx: &DawContext,
    track_id: u32,
) -> Vec<(u32, u32, AutomationLaneDto)> {
    automation_api::get_automation_lanes_for_track(ctx, track_id.into())
        .into_iter()
        .map(|(mod_id, automation_id, lane)| {
            let lane_dto = (&lane).into();
            (mod_id.into(), automation_id.into(), lane_dto)
        })
        .collect()
}

/// Fetch the list of (modulation_id, automation_id, automation_lane) where
/// the target is the given bus id
pub fn get_automation_lanes_for_bus(
    ctx: &DawContext,
    bus_id: u32,
) -> Vec<(u32, u32, AutomationLaneDto)> {
    automation_api::get_automation_lanes_for_bus(ctx, bus_id.into())
        .into_iter()
        .map(|(mod_id, automation_id, lane)| {
            let lane_dto = (&lane).into();
            (mod_id.into(), automation_id.into(), lane_dto)
        })
        .collect()
}

pub fn add_automation_lane(
    ctx: &mut DawContext,
    target: AutomationTargetDto,
    label: &str,
    min: f64,
    max: f64,
    default_value: f64,
) -> Result<(AutomationLaneDto, ModulationLinkDto), String> {
    match automation_api::add_automation_lane(ctx, target.into(), label, min, max, default_value) {
        Ok((lane, mod_link)) => {
            let lane_dto = AutomationLaneDto::from(&lane);
            let mod_link_dto = ModulationLinkDto::from(&mod_link);
            Ok((lane_dto, mod_link_dto))
        }
        Err(e) => Err(e.to_string()),
    }
}

/// Fetch all automation lanes across all targets
pub fn get_automations_lanes_all(ctx: &DawContext) -> HashMap<u32, AutomationLaneDto> {
    automation_api::get_automations_lanes_all(ctx, |lane| {
        (lane.id.into(), AutomationLaneDto::from(lane))
    })
}

/// Fetch a single automation lane
pub fn get_automation_lane(ctx: &DawContext, lane_id: u32) -> Option<AutomationLaneDto> {
    automation_api::get_automation_lane(ctx, lane_id).map(|l| (&l).into())
}

pub fn add_automation_lane_for_track(
    ctx: &mut DawContext,
    track_id: u32,
    target: AutomationTargetDto,
    label: &str,
    min: f64,
    max: f64,
    default_value: f64,
) -> Result<AutomationLaneDto, String> {
    match automation_api::add_automation_lane_for_track(
        ctx,
        track_id.into(),
        target.into(),
        label,
        min,
        max,
        default_value,
    ) {
        Ok(lane) => {
            let lane_dto = AutomationLaneDto::from(&lane);
            Ok(lane_dto)
        }
        Err(e) => Err(e.to_string()),
    }
}

pub fn add_automation_lane_for_bus(
    ctx: &mut DawContext,
    bus_id: u32,
    target: AutomationTargetDto,
    label: &str,
    min: f64,
    max: f64,
    default_value: f64,
) -> Result<AutomationLaneDto, String> {
    match automation_api::add_automation_lane_for_bus(
        ctx,
        bus_id.into(),
        target.into(),
        label,
        min,
        max,
        default_value,
    ) {
        Ok(lane) => {
            let lane_dto = AutomationLaneDto::from(&lane);
            Ok(lane_dto)
        }
        Err(e) => Err(e.to_string()),
    }
}

/// ## Overview
/// 
/// Remove automation lane for target. also cascade remove all modulations linked to it
/// 
/// ## Returns
/// 
/// * Tuple of (removed_automation_id, removed_modulation_source_ids, removed_modulation_link_ids)
pub fn remove_automation_lane_for(
    ctx: &mut DawContext,
    target: AutomationTargetDto,
) -> Result<(u32, Vec<u32>, Vec<u32>), String> {
    automation_api::remove_automation_lane(ctx, target.into())
        .map(|(automation_id, mod_ids, mod_link_ids)| {
            (
                automation_id.to_u32(),
                mod_ids.into_iter().map(|m| m.to_u32()).collect(),
                mod_link_ids.into_iter().map(|m| m.to_u32()).collect(),
            )
        })
        .map_err(|e| e.to_string())
}

pub fn add_new_automation_point(
    ctx: &mut DawContext,
    automation_id: u32,
    time_ticks: u32,
    value: f64,
) -> Result<AutomationLaneDto, String> {
    // we will warn if the value is not in normalized value
    if value > 1.0 || value < 0.0 {
        log::warn!("Value are not in correct range. it will be clamped");
    }
    let normalized_val = NormalizedF64::new(value);
    automation_api::add_new_automation_point(ctx, automation_id.into(), time_ticks, normalized_val)
        .map(|(lane, _)| (&lane).into())
        .map_err(|e| e.to_string())
}

pub fn remove_automation_point(
    ctx: &mut DawContext,
    automation_id: u32,
    id: u64,
) -> Result<AutomationLaneDto, String> {
    automation_api::remove_automation_point(ctx, automation_id.into(), id)
        .map(|l| (&l).into())
        .map_err(|e| e.to_string())
}

pub fn update_automation_point(
    ctx: &mut DawContext,
    automation_id: u32,
    id: u64,
    time_ticks: Option<u32>,
    value: Option<f64>,
    tension: Option<f64>,
    curve_type: Option<AutomationCurveTypeDto>,
) -> Result<usize, String> {
    let some_value = value.map(|v| {
        if v > 1.0 || v < 0.0 {
            log::warn!("Value are not in correct range. it will be clamped");
        }

        NormalizedF64::new(v)
    });

    let some_tension = tension.map(|t| {
        if t < -1.0 || t > 1.0 {
            log::warn!("Tension are not in correct range. it will be clamped");
        }

        BipolarF64::new(t)
    });

    automation_api::update_automation_point(
        ctx,
        automation_id.into(),
        id,
        time_ticks,
        some_value,
        some_tension,
        curve_type.map(|ct| ct.into()),
    )
    .map_err(|e| e.to_string())
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Modulation API
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Get all modulations in the project
pub fn get_all_linked_modulation_params(ctx: &DawContext) -> HashMap<u32, ModulationLinkDto> {
    automation_api::get_all_linked_modulation_params(ctx, |id, mod_link| {
        (id.to_u32(), mod_link.into())
    })
}

/// Add generic modulation source
pub fn add_modulation_source(ctx: &mut DawContext, source: ModulationSourceDto) -> u32 {
    automation_api::add_modulation_source(ctx, source.into()).to_u32()
}

/// Remove the modulation source. This function also cascade delete all link
/// with this source
pub fn remove_modulation_source(ctx: &mut DawContext, mod_id: u32) {
    automation_api::remove_modulation_source(ctx, mod_id.into());
}

/// Remove modulation link based on queried modulation link id
pub fn remove_modulation_link(ctx: &mut DawContext, mod_link_id: u32) {
    automation_api::remove_modulation_link(ctx, mod_link_id.into());
}

/// Link the target param to a modulation source
pub fn link_this_param_to_controller(
    ctx: &mut DawContext,
    source_id: u32,
    target: AutomationTargetDto,
    depth: f32,
    base_value: f32,
) -> Result<u32, String> {
    automation_api::link_this_param_to_controller(
        ctx,
        source_id.into(),
        target.into(),
        depth,
        base_value,
    )
    .map_err(|e| e.to_string())
    .and_then(|v| Ok(v.to_u32()))
}

pub fn get_modulation_link_by_id(ctx: &DawContext, link_id: u32) -> Option<ModulationLinkDto> {
    automation_api::get_modulation_link_by_id(ctx, link_id).map(|m| (&m).into())
}

pub fn get_all_modulation_sources(ctx: &DawContext) -> HashMap<u32, ModulationSourceDto> {
    automation_api::get_modulation_sources_map(ctx)
}

pub fn get_modulation_source(ctx: &DawContext, id: u32) -> Option<ModulationSourceDto> {
    automation_api::get_modulation_source(ctx, id)
}
