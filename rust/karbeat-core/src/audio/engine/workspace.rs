use hashbrown::HashMap;

use crate::{
    audio::engine::runtime::consts::MAX_ENGINE_CHANNELS, core::project::SidechainRoute,
    shared::BusId,
};

pub(super) struct RenderWorkspace {
    pub mix_buffer: Vec<f32>,
    pub bus_buffers: HashMap<BusId, Vec<f32>>,
    pub bus_temp_buffer: Vec<f32>,
    pub aux_buffers: HashMap<SidechainRoute, Vec<f32>>,

    pub channel_buffers_in: Vec<Vec<f32>>,
    pub channel_buffers_out: Vec<Vec<f32>>,
    pub aux_channel_buffers: Vec<Vec<f32>>,

}

impl RenderWorkspace {
    pub fn new(max_frames: usize, num_channels: u16) -> Self {
        let max_plugin_frames = max_frames.max(4096);
        let max_plugin_channels = num_channels.min(MAX_ENGINE_CHANNELS) as usize;
        let interleaved_samples = max_frames * max_plugin_channels;

        Self {
            mix_buffer: Vec::with_capacity(interleaved_samples),
            bus_buffers: HashMap::new(),
            bus_temp_buffer: Vec::with_capacity(interleaved_samples),
            aux_buffers: HashMap::new(),

            channel_buffers_in: (0..max_plugin_channels)
                .map(|_| vec![0.0; max_plugin_frames])
                .collect(),

            channel_buffers_out: (0..max_plugin_channels)
                .map(|_| vec![0.0; max_plugin_frames])
                .collect(),

            aux_channel_buffers: (0..max_plugin_channels)
                .map(|_| vec![0.0; max_plugin_frames])
                .collect(),

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
