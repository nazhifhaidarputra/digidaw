use std::sync::Arc;

use crate::{
    context::utils::broadcast_state_change,
    core::project::{
        automation::{AutomationLane, AutomationPoint, AutomationTarget},
        ModulationEvent,
    },
    lock::{get_app_read, get_app_write},
    shared::{AutomationId, BusId, ModulationId, ModulationLinkId, TrackId},
};

/// Get all automations lane for all types
pub fn get_automations_lanes_all<C, U, M>(mapper: M) -> C
where
    M: Fn(&AutomationLane) -> U,
    C: FromIterator<U>,
{
    let app = get_app_read();

    app.automation_pool
        .values()
        .map(|a| mapper(a.as_ref()))
        .collect()
}

pub fn add_automation_lane_for_track(
    track_id: TrackId,
    target: AutomationTarget,
    label: impl Into<String>,
    min: f32,
    max: f32,
    default_value: f32,
) -> anyhow::Result<Arc<AutomationLane>> {
    let (lane, _link_id) = {
        let mut app = get_app_write();
        app.add_automation_lane_for_track(track_id, target, label, min, max, default_value)?
    };

    broadcast_state_change();

    // TODO: add history

    Ok(lane)
}

pub fn add_automation_lane(
    target: AutomationTarget,
    label: impl Into<String>,
    min: f32,
    max: f32,
    default_value: f32,
) -> anyhow::Result<Arc<AutomationLane>> {
    let lane = {
        let mut app = get_app_write();
        let (lane, _mod_id) = app.add_automation_lane(target, label, min, max, default_value)?;
        lane
    };

    broadcast_state_change();

    // TODO: add history

    Ok(lane)
}

pub fn add_automation_lane_for_bus(
    bus_id: BusId,
    target: AutomationTarget,
    label: impl Into<String>,
    min: f32,
    max: f32,
    default_value: f32,
) -> anyhow::Result<Arc<AutomationLane>> {
    let lane = {
        let mut app = get_app_write();
        let (lane, _mod_id) =
            app.add_automation_lane_for_bus(bus_id, target, label, min, max, default_value)?;

        lane
    };

    broadcast_state_change();

    // TODO: add history

    Ok(lane)
}

// pub fn remove_automation_lane(automation_id: AutomationId) -> anyhow::Result<()> {
//     {
//         let mut app = get_app_write();
//         app.remove_automation_lane(automation_id)?;
//     }

//     broadcast_state_change();
//     Ok(())
// }

pub fn add_new_automation_point(
    automation_id: AutomationId,
    time_ticks: u32,
    value: f32,
) -> anyhow::Result<AutomationPoint> {
    let auto_point = {
        let mut app = get_app_write();
        let point = AutomationPoint::new(time_ticks, value);
        app.add_automation_point(automation_id, time_ticks, value)?;
        point
    };

    broadcast_state_change();

    // TODO: Add history
    Ok(auto_point)
}

pub fn remove_automation_point(automation_id: AutomationId, index: usize) -> anyhow::Result<()> {
    {
        let mut app = get_app_write();
        app.remove_automation_point(automation_id, index)?;
    }
    broadcast_state_change();
    Ok(())
}

pub fn update_automation_point(
    automation_id: AutomationId,
    index: usize,
    time_ticks: u32,
    value: f32,
    tension: f32,
) -> anyhow::Result<usize> {
    let new_index = {
        let mut app = get_app_write();

        let (_, new_index) =
            app.update_automation_point(automation_id, index, time_ticks, value, tension)?;
        new_index
    };

    broadcast_state_change();
    Ok(new_index) // FIXME: update the app.update_autoation_point to return new index
}

pub fn get_automation_lanes_for_track(
    track_id: TrackId,
) -> Vec<(ModulationLinkId, AutomationId, Arc<AutomationLane>)> {
    let lanes = {
        let app = get_app_read();
        app.get_automation_lanes_for_track(track_id)
    };

    lanes
}

pub fn get_automation_lanes_for_bus(
    bus_id: BusId,
) -> Vec<(ModulationLinkId, AutomationId, Arc<AutomationLane>)> {
    let app = get_app_read();
    app.get_automation_lanes_for_bus(bus_id)
}

// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
// Modulation API
// ▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱

/// Get all modulations in the project
pub fn get_all_linked_modulation_params<Id, T, F>(f: F) -> Vec<(Id, T)>
where
    F: Fn(&ModulationId, &ModulationEvent) -> (Id, T),
{
    let app = get_app_read();
    app.modulation_pool
        .iter()
        .map(|(id, modulation)| f(id, modulation))
        .collect()
}

// pub fn link_this_param_to_controller(source: ModulationEvent) -> anyhow::Result<ModulationLinkId> {
//     // let id = {
//     //     let mut app = get_app_write();
//     //     app.add_modulation(source)
//     // }?;

//     // broadcast_state_change();
//     // Ok(id)
// }
