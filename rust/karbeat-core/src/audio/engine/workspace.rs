use std::num::NonZero;

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

    pub max_plugin_frames: usize,
    pub max_plugin_channels: usize,
}

impl RenderWorkspace {
    pub fn new(max_frames: usize, num_channels: u16) -> Self {
        let max_plugin_frames = max_frames.max(4096);
        let max_plugin_channels = num_channels.min(MAX_ENGINE_CHANNELS) as usize;

        Self {
            mix_buffer: Vec::with_capacity(4096),
            bus_buffers: HashMap::new(),
            bus_temp_buffer: Vec::with_capacity(4096),
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

            max_plugin_frames,
            max_plugin_channels,
        }
    }
}
