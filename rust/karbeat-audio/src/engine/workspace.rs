use hashbrown::HashMap;

use karbeat_core::{core::project::SidechainRoute, shared::BusId};

pub(super) struct RenderWorkspace {
    /// Sized for one block of interleaved samples; its capacity sizes every node buffer.
    pub mix_buffer: Vec<f32>,
    pub bus_buffers: HashMap<BusId, Vec<f32>>,
    pub aux_buffers: HashMap<SidechainRoute, Vec<f32>>,
}

impl RenderWorkspace {
    pub fn new(max_frames: usize, num_channels: u16) -> Self {
        let channels = num_channels.min(super::runtime::consts::MAX_ENGINE_CHANNELS) as usize;
        Self {
            mix_buffer: Vec::with_capacity(max_frames * channels),
            bus_buffers: HashMap::new(),
            aux_buffers: HashMap::new(),
        }
    }

    pub fn prepare_bus(&mut self, bus_id: BusId) {
        self.bus_buffers
            .entry(bus_id)
            .or_insert_with(|| Vec::with_capacity(self.mix_buffer.capacity()));
    }

    pub fn prepare_sidechain(&mut self, route: SidechainRoute) {
        self.aux_buffers
            .entry(route)
            .or_insert_with(|| Vec::with_capacity(self.mix_buffer.capacity()));
    }
}
