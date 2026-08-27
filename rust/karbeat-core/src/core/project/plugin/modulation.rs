use anyhow::anyhow;
use hashbrown::HashSet;
use karbeat_utils::types::{BipolarF64, NormalizedF64};
use serde::{Deserialize, Serialize};

use crate::{
    audio::event::PluginTarget,
    core::project::{
        ApplicationState, AutomationCurveType, AutomationLane, AutomationPoint,
        automation::AutomationTarget,
    },
    shared::{AutomationId, BusId, ModulationId, ModulationLinkId, TrackId},
};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum ModulationEvent {
    /// Driven by the audio output of a specific plugin (e.g., Peak Controller)
    PeakController {
        source: PluginTarget,
        target: AutomationTarget,
        depth: f32,
        base_value: f32,
    },
    /// Driven by a timeline automation lane
    Automation {
        lane_id: AutomationId,
        target: AutomationTarget,
    },
    /// Driven by a mathematical oscillator (LFO)
    LFO {
        rate_hz: f32,
        depth: f32,
        base_value: f32,
        target: AutomationTarget,
    },
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub enum ModulationSource {
    PeakController { source: PluginTarget },
    Automation { lane_id: AutomationId },
    LFO { rate_hz: f32 },
    // Future: Envelope, MacroKnob, StepSequencer, etc.
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ModulationLink {
    pub id: ModulationLinkId,
    pub source_id: ModulationId,  // Which LFO/Macro is driving this?
    pub target: AutomationTarget, // What parameter is being turned?
    pub depth: f32,               // How much is it turning? (-1.0 to 1.0)
    pub base_value: f32,          // The center point of the parameter
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
pub struct ModulationLinkForOrderedLaneView {
    pub order_idx: usize,
    pub prop: ModulationLink,
}

impl ModulationEvent {
    pub fn target(&self) -> &AutomationTarget {
        match self {
            ModulationEvent::PeakController { target, .. } => target,
            ModulationEvent::Automation { target, .. } => target,
            ModulationEvent::LFO { target, .. } => target,
        }
    }
}

impl ApplicationState {
    // =========================================================================
    // MODULATION ROUTING (The Generic Master Methods)
    // =========================================================================

    /// Creates a new signal generator (e.g., an LFO)
    pub fn add_modulation_source(&mut self, source: ModulationSource) -> ModulationId {
        self.modulation_sources.insert(source)
    }

    /// Removes a generator AND all cables connected to it
    pub fn remove_modulation_source(&mut self, source_id: ModulationId) {
        self.modulation_sources.remove(source_id);
        // Cascade delete: Remove any cables that were plugged into this source
        self.modulation_links
            .retain(|_, link| link.prop.source_id != source_id);
    }

    /// Connects a Generator to a Parameter
    pub fn link_modulation(
        &mut self,
        source_id: ModulationId,
        target: AutomationTarget,
        depth: f32,
        base_value: f32,
    ) -> anyhow::Result<ModulationLinkId> {
        // Ensure the source actually exists
        if !self.modulation_sources.contains_key(source_id) {
            return Err(anyhow::anyhow!("Modulation source not found"));
        }

        // Check if THIS specific source is already linked to THIS specific target.
        if self
            .modulation_links
            .values()
            .any(|l| l.prop.source_id == source_id && l.prop.target == target)
        {
            return Err(anyhow::anyhow!(
                "This source is already linked to this target"
            ));
        }

        let order_idx = self
            .modulation_links
            .values()
            .filter(|l| l.prop.target == target)
            .count();

        let link_id =
            self.modulation_links
                .insert_with_key(|id| ModulationLinkForOrderedLaneView {
                    order_idx,
                    prop: ModulationLink {
                        id,
                        source_id,
                        target,
                        depth,
                        base_value,
                    },
                });
        log::info!(
            "Successfully linked source {:?} to target via link2 {:?}",
            source_id,
            link_id
        );

        Ok(link_id)
    }

    /// Change the depth/amount of a specific connection
    pub fn update_link_depth(&mut self, link_id: ModulationLinkId, new_depth: f32) {
        if let Some(link) = self.modulation_links.get_mut(link_id) {
            link.prop.depth = new_depth;
        }
    }

    /// Removes a specific connection
    pub fn remove_modulation_link(&mut self, link_id: ModulationLinkId) {
        self.modulation_links.remove(link_id);
    }

    // =========================================================================
    // AUTOMATION POOL MANAGEMENT (Using the Generic Routing)
    // =========================================================================

    /// Add an automation lane to the pool and link it to a target.
    pub fn add_automation_lane(
        &mut self,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f64,
        max: f64,
        default_value: f64,
    ) -> anyhow::Result<(AutomationLane, ModulationLinkId)> {
        // === PREVENT DUPLICATES ===
        // Check if this exact target already has an Automation source linked to it.
        let already_automated = self.modulation_links.values().any(|link| {
            if link.prop.target == target {
                // If it's linked to an Automation lane, reject it!
                matches!(
                    self.modulation_sources.get(link.prop.source_id),
                    Some(ModulationSource::Automation { .. })
                )
            } else {
                false
            }
        });

        if already_automated {
            return Err(anyhow::anyhow!(
                "An automation lane already exists for this parameter."
            ));
        }

        // Create the Lane (Pure Data)
        let label = label.into();
        let lane_id = self
            .automation_pool
            .insert_with_key(|id| AutomationLane::new(id, label, min, max, default_value));
        let lane = self.automation_pool[lane_id].clone();

        // Create the Source Generator
        let source = ModulationSource::Automation { lane_id };
        let source_id = self.add_modulation_source(source);

        // Connect the Cable (Depth 1.0, Base Value 0.0 for standard 1:1 automation tracking)
        let link_id = self.link_modulation(source_id, target, 1.0, 0.0)?;

        log::info!(
            "Added automation lane {:?} mapped via link {:?}",
            lane_id,
            link_id
        );
        Ok((lane, link_id))
    }

    /// Add an automation lane specifically validated for a Track target.
    pub fn add_automation_lane_for_track(
        &mut self,
        track_id: TrackId,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f64,
        max: f64,
        default_value: f64,
    ) -> anyhow::Result<(AutomationLane, ModulationLinkId)> {
        if !target.references_track(track_id) {
            return Err(anyhow!("Target does not reference the specified track"));
        }
        self.add_automation_lane(target, label, min, max, default_value)
    }

    /// Get all Modulations AND their associated Automation Lanes for a specific Track.
    pub fn get_automation_lanes_for_track(
        &self,
        track_id: TrackId,
    ) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
        let mut lanes: Vec<_> = self
            .modulation_links
            .values()
            .filter_map(|link| {
                if link.prop.target.references_track(track_id) {
                    if let Some(ModulationSource::Automation { lane_id }) =
                        self.modulation_sources.get(link.prop.source_id)
                    {
                        if let Some(lane) = self.automation_pool.get(*lane_id) {
                            return Some((link.order_idx, link.prop.id, *lane_id, lane.clone()));
                        }
                    }
                }
                None
            })
            .collect();

        lanes.sort_by_key(|item| item.0);
        lanes
            .into_iter()
            .map(|item| (item.1, item.2, item.3))
            .collect()
    }

    /// remove automation lane, also remove orphaned modulation source and modulation links which links to this automation lane.
    /// returns all removed data
    pub fn remove_automation_lane(
        &mut self,
        target: AutomationTarget,
    ) -> Option<(
        AutomationId,
        HashSet<ModulationId>,
        HashSet<ModulationLinkId>,
    )> {
        let mut removed_sources = HashSet::new();
        let mut removed_links = HashSet::new();
        let mut main_lane_id = None;

        // Identify all links mapped to this target that are driven by an Automation Lane
        let mut to_remove = Vec::new();
        for (link_id, link) in self.modulation_links.iter() {
            if link.prop.target == target {
                if let Some(ModulationSource::Automation { lane_id }) =
                    self.modulation_sources.get(link.prop.source_id)
                {
                    to_remove.push((link_id, link.prop.source_id, *lane_id));
                }
            }
        }

        // Perform the removals from the application state
        for (link_id, source_id, lane_id) in to_remove {
            if self.modulation_links.remove(link_id).is_some() {
                removed_links.insert(link_id); // HashSet uses insert()
            }
            if self.modulation_sources.remove(source_id).is_some() {
                removed_sources.insert(source_id); // HashSet uses insert()
            }
            if self.automation_pool.remove(lane_id).is_some() {
                // Capture the first lane_id we find to return it
                if main_lane_id.is_none() {
                    main_lane_id = Some(lane_id);
                }
            }
        }

        // Map the found lane_id with the collected HashSets, otherwise return None
        main_lane_id.map(|id| (id, removed_sources, removed_links))
    }

    /// Completely remove all Modulation Links and orphaned Automation Lanes for a Track.
    pub fn remove_modulations_for_track(&mut self, track_id: TrackId) {
        let mut orphaned_lanes = Vec::new();

        self.modulation_links.retain(|_, link| {
            let references = link.prop.target.references_track(track_id);

            if references {
                if let Some(ModulationSource::Automation { lane_id }) =
                    self.modulation_sources.get(link.prop.source_id)
                {
                    orphaned_lanes.push(*lane_id);
                }
            }
            !references // Keep if it does NOT reference the track
        });

        // Clean up the pure data lanes so we don't leak memory
        for lane_id in orphaned_lanes {
            self.automation_pool.remove(lane_id);
        }
    }

    /// Add an automation lane specifically validated for a Bus target.
    pub fn add_automation_lane_for_bus(
        &mut self,
        bus_id: BusId,
        target: AutomationTarget,
        label: impl Into<String>,
        min: f64,
        max: f64,
        default_value: f64,
    ) -> anyhow::Result<(AutomationLane, ModulationLinkId)> {
        if !target.references_bus(bus_id) {
            return Err(anyhow!("Target does not reference the specified bus"));
        }
        self.add_automation_lane(target, label, min, max, default_value)
    }

    /// Get all Modulations AND their associated Automation Lanes for a specific Bus.
    pub fn get_automation_lanes_for_bus(
        &self,
        bus_id: BusId,
    ) -> Vec<(ModulationLinkId, AutomationId, AutomationLane)> {
        let mut lanes: Vec<_> = self
            .modulation_links
            .values()
            .filter_map(|link| {
                if link.prop.target.references_bus(bus_id) {
                    if let Some(ModulationSource::Automation { lane_id }) =
                        self.modulation_sources.get(link.prop.source_id)
                    {
                        if let Some(lane) = self.automation_pool.get(*lane_id) {
                            return Some((link.order_idx, link.prop.id, *lane_id, lane.clone()));
                        }
                    }
                }
                None
            })
            .collect();

        lanes.sort_by_key(|item| item.0);
        lanes
            .into_iter()
            .map(|item| (item.1, item.2, item.3))
            .collect()
    }

    /// Completely remove all Modulations and orphaned Automation Lanes for a Bus.
    pub fn remove_modulations_for_bus(&mut self, bus_id: BusId) {
        let mut orphaned_lanes = Vec::new();

        self.modulation_links.retain(|_, link| {
            let references = link.prop.target.references_bus(bus_id);
            if references {
                if let Some(ModulationSource::Automation { lane_id }) =
                    self.modulation_sources.get(link.prop.source_id)
                {
                    orphaned_lanes.push(*lane_id);
                }
            }
            !references
        });

        for lane_id in orphaned_lanes {
            self.automation_pool.remove(lane_id);
        }
    }

    /// Add a Host LFO to control a parameter (Example of generic usage)
    pub fn add_lfo_modulation(
        &mut self,
        target: AutomationTarget,
        rate_hz: f32,
        depth: f32,
        base_value: f32,
    ) -> anyhow::Result<ModulationLinkId> {
        let source_id = self.add_modulation_source(ModulationSource::LFO { rate_hz });
        self.link_modulation(source_id, target, depth, base_value)
    }

    // =========================================================================
    // AUTOMATION POINT MANAGEMENT
    // =========================================================================
    pub fn add_automation_point(
        &mut self,
        lane_id: AutomationId,
        time_ticks: u32,
        value: NormalizedF64,
    ) -> anyhow::Result<(AutomationLane, u64)> {
        // AutomationPoint::new applies Linear curve and clamps safely to 0.0..1.0
        let point = AutomationPoint::new(time_ticks, value);
        let point_id = self
            .automation_pool
            .get_mut(lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?
            .add_point(point)
            .to_u64();
        let lane = &self.automation_pool[lane_id];
        Ok((lane.clone(), point_id))
    }

    pub fn remove_automation_point(
        &mut self,
        lane_id: AutomationId,
        point_id: u64,
    ) -> anyhow::Result<AutomationLane> {
        let lane = self
            .automation_pool
            .get_mut(lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;

        let _ = lane
            .remove_point(point_id)
            .ok_or_else(|| anyhow!("Point ID {} not found in lane {:?}", point_id, lane_id));

        Ok(lane.clone())
    }

    pub fn update_automation_point(
        &mut self,
        lane_id: AutomationId,
        point_id: u64,
        time_ticks: Option<u32>,
        value: Option<NormalizedF64>,
        tension: Option<BipolarF64>,
        curve_type: Option<AutomationCurveType>,
    ) -> anyhow::Result<(AutomationLane, usize)> {
        let lane = self
            .automation_pool
            .get_mut(lane_id)
            .ok_or_else(|| anyhow!("Automation lane {:?} not found", lane_id))?;

        match lane.update_point(point_id, time_ticks, value, tension, curve_type) {
            Some(new_index) => Ok((lane.clone(), new_index)),
            None => Err(anyhow!(
                "Point ID {} not found in lane {:?}",
                point_id,
                lane_id
            )),
        }
    }

    /// ======================================
    /// Update Modulation Link Order (Drag and Drop UI Support)
    /// Scopes the sorting strictly to the UI accordion/drawer.
    /// ======================================
    pub fn update_link_order(
        &mut self,
        link_id: ModulationLinkId,
        new_idx: usize,
    ) -> anyhow::Result<()> {
        // Find the target to determine which UI drawer we are sorting inside
        let target = self
            .modulation_links
            .get(link_id)
            .map(|l| l.prop.target.clone())
            .ok_or_else(|| anyhow::anyhow!("Link {:?} not found", link_id))?;

        // Gather ALL links that live in this exact same UI drawer
        let mut sibling_links: Vec<_> = self
            .modulation_links
            .values()
            .filter(|l| l.prop.target.belongs_to_same_drawer_as(&target))
            .cloned()
            .collect();

        // Sort them by their current UI order
        sibling_links.sort_by_key(|link| link.order_idx);

        // Find the link's current position among its siblings
        if let Some(current_pos) = sibling_links
            .iter()
            .position(|link| link.prop.id == link_id)
        {
            // Move the link in the sorted vector
            let target_idx = new_idx.min(sibling_links.len().saturating_sub(1));
            let link = sibling_links.remove(current_pos);
            sibling_links.insert(target_idx, link);
        }

        // Write the new sequential indices back to the global HashMap
        for (i, sibling) in sibling_links.iter().enumerate() {
            if let Some(global_link) = self.modulation_links.get_mut(sibling.prop.id) {
                global_link.order_idx = i;
            }
        }

        Ok(())
    }
}
