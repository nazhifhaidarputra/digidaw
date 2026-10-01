use std::collections::HashMap;

use flutter_rust_bridge::frb;
use karbeat_core::{
    core::project::{
        AutomationCurveType, AutomationLane, AutomationPoint, AutomationTarget, BezierHandles,
        EffectAutomationTarget, MasterAutomationTarget, MixerChannelParamTarget, ModulationLink,
        ModulationLinkForOrderedLaneView, ModulationSource, RemovedModulations,
        TrackAutomationTarget, interpolate_points_at, interpolate_segment, tension_count,
    },
    shared::{BusId, EffectId, TrackId},
};
use karbeat_core_api::automation_api;
use karbeat_utils::types::{BipolarF64, NormalizedF64};

use crate::api::{context::DawContext, plugin::UiPluginTarget};

#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct AutomationLaneDto {
    pub id: u64,
    pub label: String,
    /// Points in engine order, with normalized values (0.0 to 1.0).
    pub points: Vec<AutomationPointDto>,
    pub enabled: bool,
    /// Normalized value held while the lane has no points.
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
    /// Bezier handles of the segment to the next point; only Bezier segments use them.
    pub handles: Option<BezierHandlesDto>,
}

/// Control handles of a Bezier segment. `x` is a fraction of the segment's duration and `y` a
/// normalized lane value, both 0.0 to 1.0.
#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct BezierHandlesDto {
    pub x1: f64,
    pub y1: f64,
    pub x2: f64,
    pub y2: f64,
}

impl From<BezierHandles> for BezierHandlesDto {
    fn from(handles: BezierHandles) -> Self {
        Self {
            x1: handles.x1,
            y1: handles.y1,
            x2: handles.x2,
            y2: handles.y2,
        }
    }
}

impl From<BezierHandlesDto> for BezierHandles {
    fn from(handles: BezierHandlesDto) -> Self {
        Self {
            x1: handles.x1,
            y1: handles.y1,
            x2: handles.x2,
            y2: handles.y2,
        }
    }
}

/// Which segment controls a curve type responds to, so editors stay generic over curve types.
#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct AutomationCurveTraitsDto {
    /// Whether tension changes the shape.
    pub supports_tension: bool,
    /// Whether raising tension lowers a rising segment.
    pub tension_inverted: bool,
    /// Whether tension selects a step or cycle count instead of a bend.
    pub tension_is_count: bool,
    /// Whether the shape comes from Bezier handles.
    pub uses_handles: bool,
}

/// Automation removed as part of another project operation, such as deleting an effect.
#[derive(Clone, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct RemovedAutomationDto {
    pub automation_lane_ids: Vec<u64>,
    pub modulation_source_ids: Vec<u64>,
    pub modulation_link_ids: Vec<u64>,
}

impl From<RemovedModulations> for RemovedAutomationDto {
    fn from(removed: RemovedModulations) -> Self {
        Self {
            automation_lane_ids: removed
                .automation_lanes
                .into_iter()
                .map(|id| id.to_u64())
                .collect(),
            modulation_source_ids: removed
                .modulation_sources
                .into_iter()
                .map(|id| id.to_u64())
                .collect(),
            modulation_link_ids: removed
                .modulation_links
                .into_iter()
                .map(|id| id.to_u64())
                .collect(),
        }
    }
}

#[derive(Clone, Debug)]
pub enum AutomationTargetDto {
    Generator {
        generator_id: u64,
        param_id: u32,
    },
    Track {
        track_id: u64,
        track_target: TrackAutomationTargetDto,
    },
    Bus {
        bus_id: u64,
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
        effect_id: u64,
        target: EffectAutomationTargetDto,
    },
}

#[derive(Clone, Debug)]
pub enum EffectAutomationTargetDto {
    Mix,
    PluginParam { param_id: u32 },
}

#[derive(Clone, Copy, Debug)]
pub enum AutomationCurveTypeDto {
    Linear,
    Exponential,
    Step,
    Logarithmic,
    SCurve,
    Bezier,
    Stairs,
    SmoothStairs,
    Pulse,
    Wave,
    Triangle,
    HalfSine,
}

#[frb(dart_metadata=("freezed"))]
pub struct ModulationLinkDto {
    pub id: u64,
    pub source_id: u64,              // Which LFO/Macro is driving this?
    pub target: AutomationTargetDto, // What parameter is being turned?
    pub depth: f32,                  // How much is it turning? (-1.0 to 1.0)
    pub base_value: f32,
    pub order_idx: usize,
}

pub enum ModulationSourceDto {
    PeakController { source: UiPluginTarget },
    Automation { lane_id: u64 },
    Lfo { rate_hz: f32 },
}

impl From<&ModulationSource> for ModulationSourceDto {
    fn from(value: &ModulationSource) -> Self {
        match value {
            ModulationSource::PeakController { source } => Self::PeakController {
                source: source.into(),
            },
            ModulationSource::Automation { lane_id } => Self::Automation {
                lane_id: lane_id.to_u64(),
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
            id: value.prop.id.to_u64(),
            source_id: value.prop.source_id.to_u64(),
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
            AutomationCurveType::Logarithmic => Self::Logarithmic,
            AutomationCurveType::SCurve => Self::SCurve,
            AutomationCurveType::Bezier => Self::Bezier,
            AutomationCurveType::Stairs => Self::Stairs,
            AutomationCurveType::SmoothStairs => Self::SmoothStairs,
            AutomationCurveType::Pulse => Self::Pulse,
            AutomationCurveType::Wave => Self::Wave,
            AutomationCurveType::Triangle => Self::Triangle,
            AutomationCurveType::HalfSine => Self::HalfSine,
        }
    }
}

impl From<AutomationCurveTypeDto> for AutomationCurveType {
    fn from(value: AutomationCurveTypeDto) -> Self {
        match value {
            AutomationCurveTypeDto::Linear => Self::Linear,
            AutomationCurveTypeDto::Exponential => Self::Exponential,
            AutomationCurveTypeDto::Step => Self::Step,
            AutomationCurveTypeDto::Logarithmic => Self::Logarithmic,
            AutomationCurveTypeDto::SCurve => Self::SCurve,
            AutomationCurveTypeDto::Bezier => Self::Bezier,
            AutomationCurveTypeDto::Stairs => Self::Stairs,
            AutomationCurveTypeDto::SmoothStairs => Self::SmoothStairs,
            AutomationCurveTypeDto::Pulse => Self::Pulse,
            AutomationCurveTypeDto::Wave => Self::Wave,
            AutomationCurveTypeDto::Triangle => Self::Triangle,
            AutomationCurveTypeDto::HalfSine => Self::HalfSine,
        }
    }
}

impl From<AutomationPointDto> for AutomationPoint {
    fn from(point: AutomationPointDto) -> Self {
        Self {
            id: point.id.into(),
            time_ticks: point.time_ticks,
            value: NormalizedF64::new(point.value),
            curve_type: point.curve_type.into(),
            tension: BipolarF64::new(point.tension),
            handles: point.handles.map(Into::into),
        }
    }
}

impl From<AutomationPoint> for AutomationPointDto {
    fn from(p: AutomationPoint) -> Self {
        Self {
            id: p.id.to_u64(),
            time_ticks: p.time_ticks,
            value: p.value.get(),
            curve_type: p.curve_type.into(),
            tension: p.tension.get(),
            handles: p.handles.map(Into::into),
        }
    }
}

impl TryFrom<AutomationLaneDto> for AutomationLane {
    type Error = &'static str;

    fn try_from(l: AutomationLaneDto) -> Result<Self, Self::Error> {
        // If Flutter sends 1.5, this explicitly throws an Error
        let default_value = NormalizedF64::try_from(l.default_value)?;

        let points: Vec<AutomationPoint> = l
            .points
            .into_iter()
            .filter_map(|p| p.try_into().ok())
            .collect();
        let next_point_id = points
            .iter()
            .map(|point| point.id.to_u32())
            .max()
            .map_or(0, |id| id.saturating_add(1));

        Ok(Self {
            id: l.id.into(),
            label: l.label,
            points,
            next_point_id,
            enabled: l.enabled,
            default_value,
        })
    }
}

impl From<&AutomationLane> for AutomationLaneDto {
    fn from(l: &AutomationLane) -> Self {
        Self {
            id: l.id.to_u64(),
            label: l.label.clone(),
            points: l.points.iter().map(|p| p.to_owned().into()).collect(),
            enabled: l.enabled,
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
                effect_id: effect_id.to_u64(),
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
                track_id: track_id.to_u64(),
                track_target: TrackAutomationTargetDto::from(track_target),
            },
            AutomationTarget::Bus { bus_id, mix_target } => Self::Bus {
                bus_id: bus_id.to_u64(),
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
                generator_id: generator_id.to_u64(),
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
                effect_id: EffectId::from_u64(effect_id),
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
                track_id: TrackId::from_u64(track_id),
                track_target: TrackAutomationTarget::from(track_target),
            },
            AutomationTargetDto::Bus { bus_id, mix_target } => Self::Bus {
                bus_id: BusId::from_u64(bus_id),
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
    track_id: u64,
) -> Vec<(u64, u64, AutomationLaneDto)> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_automation_lanes_for_track(ctx, TrackId::from_u64(track_id))
        .into_iter()
        .map(|(mod_id, automation_id, lane)| {
            let lane_dto = (&lane).into();
            (mod_id.to_u64(), automation_id.to_u64(), lane_dto)
        })
        .collect()
}

/// Fetch the list of (modulation_id, automation_id, automation_lane) where
/// the target is the given bus id
pub fn get_automation_lanes_for_bus(
    ctx: &DawContext,
    bus_id: u64,
) -> Vec<(u64, u64, AutomationLaneDto)> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_automation_lanes_for_bus(ctx, BusId::from_u64(bus_id))
        .into_iter()
        .map(|(mod_id, automation_id, lane)| {
            let lane_dto = (&lane).into();
            (mod_id.to_u64(), automation_id.to_u64(), lane_dto)
        })
        .collect()
}

/// Creates an automation lane for `target`.
///
/// `initial_value` is the parameter's current value in its own unit; the parameter normalizes
/// it. `None` starts the lane on the value stored in the project.
pub fn add_automation_lane(
    ctx: &DawContext,
    target: AutomationTargetDto,
    label: &str,
    initial_value: Option<f64>,
) -> Result<(AutomationLaneDto, ModulationLinkDto), String> {
    crate::api::context::project_ctx!(ctx);
    match automation_api::add_automation_lane(ctx, target.into(), label, initial_value) {
        Ok((lane, mod_link)) => {
            let lane_dto = AutomationLaneDto::from(&lane);
            let mod_link_dto = ModulationLinkDto::from(&mod_link);
            Ok((lane_dto, mod_link_dto))
        }
        Err(e) => Err(e.to_string()),
    }
}

/// Fetch all automation lanes across all targets
pub fn get_automations_lanes_all(ctx: &DawContext) -> HashMap<u64, AutomationLaneDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_automations_lanes_all(ctx, |lane| {
        (lane.id.to_u64(), AutomationLaneDto::from(lane))
    })
}

/// Fetch a single automation lane
pub fn get_automation_lane(ctx: &DawContext, lane_id: u64) -> Option<AutomationLaneDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_automation_lane(ctx, lane_id).map(|l| (&l).into())
}

pub fn add_automation_lane_for_track(
    ctx: &DawContext,
    track_id: u64,
    target: AutomationTargetDto,
    label: &str,
    initial_value: Option<f64>,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    match automation_api::add_automation_lane_for_track(
        ctx,
        TrackId::from_u64(track_id),
        target.into(),
        label,
        initial_value,
    ) {
        Ok(lane) => {
            let lane_dto = AutomationLaneDto::from(&lane);
            Ok(lane_dto)
        }
        Err(e) => Err(e.to_string()),
    }
}

pub fn add_automation_lane_for_bus(
    ctx: &DawContext,
    bus_id: u64,
    target: AutomationTargetDto,
    label: &str,
    initial_value: Option<f64>,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    match automation_api::add_automation_lane_for_bus(
        ctx,
        BusId::from_u64(bus_id),
        target.into(),
        label,
        initial_value,
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
    ctx: &DawContext,
    target: AutomationTargetDto,
) -> Result<(u64, Vec<u64>, Vec<u64>), String> {
    crate::api::context::project_ctx!(ctx);
    automation_api::remove_automation_lane(ctx, target.into())
        .map(|(automation_id, mod_ids, mod_link_ids)| {
            (
                automation_id.to_u64(),
                mod_ids.into_iter().map(|m| m.to_u64()).collect(),
                mod_link_ids.into_iter().map(|m| m.to_u64()).collect(),
            )
        })
        .map_err(|e| e.to_string())
}

/// Sets whether a lane controls its target while preserving its data and link.
pub fn set_automation_lane_enabled(
    ctx: &DawContext,
    automation_id: u64,
    enabled: bool,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    automation_api::set_automation_lane_enabled(ctx, automation_id.into(), enabled)
        .map(|lane| (&lane).into())
        .map_err(|e| e.to_string())
}

pub fn add_new_automation_point(
    ctx: &DawContext,
    automation_id: u64,
    time_ticks: u32,
    value: f64,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
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
    ctx: &DawContext,
    automation_id: u64,
    id: u64,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    automation_api::remove_automation_point(ctx, automation_id.into(), id)
        .map(|l| (&l).into())
        .map_err(|e| e.to_string())
}

/// Changes the supplied fields of one automation point and returns the updated lane.
#[allow(
    clippy::too_many_arguments,
    reason = "each optional field is one independently editable point property"
)]
pub fn update_automation_point(
    ctx: &DawContext,
    automation_id: u64,
    id: u64,
    time_ticks: Option<u32>,
    value: Option<f64>,
    tension: Option<f64>,
    curve_type: Option<AutomationCurveTypeDto>,
    handles: Option<BezierHandlesDto>,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
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
        handles.map(Into::into),
    )
    .map(|(lane, _)| (&lane).into())
    .map_err(|e| e.to_string())
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Range copy and paste
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Copies the curve of a lane between two ticks. Returned points have times relative to the
/// range start; a point is added on each edge the range cuts through a segment.
pub fn copy_automation_range(
    ctx: &DawContext,
    automation_id: u64,
    start_tick: u32,
    end_tick: u32,
) -> Result<Vec<AutomationPointDto>, String> {
    crate::api::context::read_ctx!(ctx);
    automation_api::copy_automation_range(ctx, automation_id.into(), start_tick, end_tick)
        .map(|points| points.into_iter().map(Into::into).collect())
        .map_err(|e| e.to_string())
}

/// Removes every point of a lane between two ticks as one undo step.
pub fn delete_automation_range(
    ctx: &DawContext,
    automation_id: u64,
    start_tick: u32,
    end_tick: u32,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    automation_api::delete_automation_range(ctx, automation_id.into(), start_tick, end_tick)
        .map(|lane| (&lane).into())
        .map_err(|e| e.to_string())
}

/// Pastes a copied curve at `at_tick` as one undo step, replacing the points under it.
///
/// `length_ticks` is the length of the copied range; `target_length` stretches the curve to
/// another length.
pub fn paste_automation_points(
    ctx: &DawContext,
    automation_id: u64,
    at_tick: u32,
    points: Vec<AutomationPointDto>,
    length_ticks: u32,
    target_length: Option<u32>,
) -> Result<AutomationLaneDto, String> {
    crate::api::context::project_ctx!(ctx);
    let points: Vec<AutomationPoint> = points.into_iter().map(Into::into).collect();
    automation_api::paste_automation_points(
        ctx,
        automation_id.into(),
        at_tick,
        &points,
        length_ticks,
        target_length,
    )
    .map(|lane| (&lane).into())
    .map_err(|e| e.to_string())
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Parameter values
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Formats a lane's normalized value in the unit of the parameter it automates.
#[frb(sync)]
pub fn automation_value_text(
    ctx: &DawContext,
    automation_id: u64,
    normalized: f64,
) -> Result<String, String> {
    crate::api::context::read_ctx!(ctx);
    automation_api::automation_value_text(ctx, automation_id.into(), NormalizedF64::new(normalized))
        .map_err(|e| e.to_string())
}

/// Parses text typed in the unit of a lane's parameter into a normalized lane value.
#[frb(sync)]
pub fn parse_automation_value(
    ctx: &DawContext,
    automation_id: u64,
    text: &str,
) -> Result<f64, String> {
    crate::api::context::read_ctx!(ctx);
    automation_api::parse_automation_value(ctx, automation_id.into(), text)
        .map(NormalizedF64::get)
        .map_err(|e| e.to_string())
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Curve drawing
//
// Flutter draws curves with these functions, which call the same code the audio engine plays.
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Samples a lane's curve at `sample_count` evenly spaced ticks from `start_tick` to `end_tick`
/// inclusive. `points` must be in lane order. Returns no samples for a lane without points.
#[frb(sync)]
pub fn sample_automation_curve(
    points: Vec<AutomationPointDto>,
    start_tick: f64,
    end_tick: f64,
    sample_count: u32,
) -> Vec<f32> {
    let points: Vec<AutomationPoint> = points.into_iter().map(Into::into).collect();
    let last = f64::from(sample_count.saturating_sub(1).max(1));
    (0..sample_count)
        .map_while(|index| {
            let tick = start_tick + (end_tick - start_tick) * f64::from(index) / last;
            interpolate_points_at(&points, tick).map(|value| narrow(value.get()))
        })
        .collect()
}

/// Value at the time midpoint of every segment of a lane, one entry per pair of consecutive
/// points. Editors place each segment's tension handle on it.
#[frb(sync)]
pub fn automation_segment_midpoints(points: Vec<AutomationPointDto>) -> Vec<f32> {
    let points: Vec<AutomationPoint> = points.into_iter().map(Into::into).collect();
    points
        .windows(2)
        .filter_map(|pair| match pair {
            [from, to] => Some(narrow(
                interpolate_segment(from, to.value, 0.5).clamp(0.0, 1.0),
            )),
            _ => None,
        })
        .collect()
}

/// Describes which segment controls a curve type responds to.
#[frb(sync)]
pub fn automation_curve_traits(curve_type: AutomationCurveTypeDto) -> AutomationCurveTraitsDto {
    let traits = AutomationCurveType::from(curve_type).traits();
    AutomationCurveTraitsDto {
        supports_tension: traits.supports_tension,
        tension_inverted: traits.tension_inverted,
        tension_is_count: traits.tension_is_count,
        uses_handles: traits.uses_handles,
    }
}

/// Step or cycle count that `tension` selects for count-driven curve types.
#[frb(sync)]
pub fn automation_tension_count(tension: f64) -> u32 {
    tension_count(tension)
}

/// Narrows a drawing sample for transfer as a flat `f32` list.
#[allow(
    clippy::as_conversions,
    reason = "curve samples are only drawn, so f32 precision is enough"
)]
fn narrow(value: f64) -> f32 {
    value as f32
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Modulation API
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Get all modulations in the project
pub fn get_all_linked_modulation_params(ctx: &DawContext) -> HashMap<u64, ModulationLinkDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_all_linked_modulation_params(ctx, |id, mod_link| {
        (id.to_u64(), mod_link.into())
    })
}

/// Add generic modulation source
pub fn add_modulation_source(ctx: &DawContext, source: ModulationSourceDto) -> u64 {
    crate::api::context::project_ctx!(ctx);
    automation_api::add_modulation_source(ctx, source.into()).to_u64()
}

/// Remove the modulation source. This function also cascade delete all link
/// with this source
pub fn remove_modulation_source(ctx: &DawContext, mod_id: u64) {
    crate::api::context::project_ctx!(ctx);
    automation_api::remove_modulation_source(ctx, mod_id.into());
}

/// Remove modulation link based on queried modulation link id
pub fn remove_modulation_link(ctx: &DawContext, mod_link_id: u64) {
    crate::api::context::project_ctx!(ctx);
    automation_api::remove_modulation_link(ctx, mod_link_id.into());
}

/// Link the target param to a modulation source
pub fn link_this_param_to_controller(
    ctx: &DawContext,
    source_id: u64,
    target: AutomationTargetDto,
    depth: f32,
    base_value: f32,
) -> Result<u64, String> {
    crate::api::context::project_ctx!(ctx);
    automation_api::link_this_param_to_controller(
        ctx,
        source_id.into(),
        target.into(),
        depth,
        base_value,
    )
    .map_err(|e| e.to_string())
    .map(|v| v.to_u64())
}

pub fn get_modulation_link_by_id(ctx: &DawContext, link_id: u64) -> Option<ModulationLinkDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_modulation_link_by_id(ctx, link_id).map(|m| (&m).into())
}

pub fn get_all_modulation_sources(ctx: &DawContext) -> HashMap<u64, ModulationSourceDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_modulation_sources_map(ctx)
}

pub fn get_modulation_source(ctx: &DawContext, id: u64) -> Option<ModulationSourceDto> {
    crate::api::context::read_ctx!(ctx);
    automation_api::get_modulation_source(ctx, id)
}
