use hashbrown::HashMap;
use karbeat_host::retire::{Owner, Retiree};

use super::runtime::consts::MAX_ENGINE_CHANNELS;
use karbeat_core::{core::project::SidechainRoute, shared::BusId};

pub(super) struct RenderWorkspace {
    /// Sized for one block of interleaved samples; its capacity sizes every node buffer.
    pub mix_buffer: Vec<f32>,
    /// Bus and sidechain buffers retire off the audio thread when removed.
    pub bus_buffers: HashMap<BusId, Retiree<Vec<f32>>>,
    pub aux_buffers: HashMap<SidechainRoute, Retiree<Vec<f32>>>,
}

impl RenderWorkspace {
    pub fn new(max_frames: usize, num_channels: u16) -> Self {
        let channels = num_channels.min(MAX_ENGINE_CHANNELS) as usize;
        Self {
            mix_buffer: Vec::with_capacity(max_frames * channels),
            bus_buffers: HashMap::new(),
            aux_buffers: HashMap::new(),
        }
    }

    // Both allocate on the audio thread when they add a buffer, as they did before buffers
    // retired through nodes; the node adds one allocation to the buffer's own.
    pub fn prepare_bus(&mut self, bus_id: BusId) {
        let capacity = self.mix_buffer.capacity();
        self.bus_buffers
            .entry(bus_id)
            .or_insert_with(|| node_buffer(capacity));
    }

    pub fn prepare_sidechain(&mut self, route: SidechainRoute) {
        let capacity = self.mix_buffer.capacity();
        self.aux_buffers
            .entry(route)
            .or_insert_with(|| node_buffer(capacity));
    }
}

fn node_buffer(capacity: usize) -> Retiree<Vec<f32>> {
    Retiree::new(Owner::AnyThread, Vec::with_capacity(capacity))
}
