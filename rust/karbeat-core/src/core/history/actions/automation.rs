use super::pools::{PoolBefore, PoolSwap};
use crate::core::{
    history::{EngineSync, HistoryAction, HistoryError},
    project::{
        ApplicationState, AutomationLane, ModulationLinkForOrderedLaneView, ModulationSource,
    },
};
use crate::shared::id::{AutomationId, ModulationId, ModulationLinkId};

/// Automation lanes, points, modulation sources, or modulation links changed.
///
/// Holds only the entries the edit created, changed, or removed, as they are on the other side
/// of the edit. Removed entries were detached, so they return under the same keys.
#[derive(Debug)]
pub struct AutomationChanged {
    label: &'static str,
    lanes: PoolSwap<AutomationId, AutomationLane>,
    sources: PoolSwap<ModulationId, ModulationSource>,
    links: PoolSwap<ModulationLinkId, ModulationLinkForOrderedLaneView>,
}

impl AutomationChanged {
    /// Whether the edit changed nothing.
    pub fn is_empty(&self) -> bool {
        self.lanes.is_empty() && self.sources.is_empty() && self.links.is_empty()
    }

    pub(crate) fn swap(&mut self, app: &mut ApplicationState) -> Result<EngineSync, HistoryError> {
        self.sources
            .swap(&mut app.modulation_sources, "Modulation source")?;
        self.lanes
            .swap(&mut app.automation_pool, "Automation lane")?;
        self.links
            .swap(&mut app.modulation_links, "Modulation link")?;

        // Point and enable edits only change existing lanes; republish just those.
        if self.sources.is_empty()
            && self.links.is_empty()
            && self.lanes.only_changes(&app.automation_pool)
        {
            let mut sync = EngineSync::none();
            for id in self.lanes.changed_keys(&app.automation_pool) {
                sync.merge(EngineSync::lane(id));
            }
            return Ok(sync);
        }
        Ok(EngineSync::full_graph())
    }
}

swap_action!(AutomationChanged, field label);

/// Captures the automation pools before an automation edit and builds the
/// [`AutomationChanged`] record afterwards.
#[derive(Debug)]
pub struct AutomationRecorder {
    lanes: PoolBefore<AutomationId, AutomationLane>,
    sources: PoolBefore<ModulationId, ModulationSource>,
    links: PoolBefore<ModulationLinkId, ModulationLinkForOrderedLaneView>,
}

impl AutomationRecorder {
    /// Snapshots the lane, modulation source, and modulation link pools.
    pub fn begin(app: &ApplicationState) -> Self {
        Self {
            lanes: PoolBefore::capture(&app.automation_pool),
            sources: PoolBefore::capture(&app.modulation_sources),
            links: PoolBefore::capture(&app.modulation_links),
        }
    }

    /// Builds the record from what the edit changed.
    pub fn finish(self, app: &ApplicationState, label: &'static str) -> AutomationChanged {
        AutomationChanged {
            label,
            lanes: self.lanes.diff(&app.automation_pool),
            sources: self.sources.diff(&app.modulation_sources),
            links: self.links.diff(&app.modulation_links),
        }
    }
}
