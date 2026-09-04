use hashbrown::HashMap;

use crate::{core::project::SidechainRoute, shared::BusId};

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
    pub fn new(buffer_size: usize, num_channels: u16) -> Self {
        let channel_buffer_len = buffer_size.max(4096);
        Self {
            mix_buffer: Vec::with_capacity(4096),
            bus_buffers: HashMap::new(),
            bus_temp_buffer: Vec::with_capacity(4096),
            aux_buffers: HashMap::new(),
            channel_buffers_in: vec![vec![0.0; channel_buffer_len]; num_channels as usize],
            channel_buffers_out: vec![vec![0.0; channel_buffer_len]; num_channels as usize],
            aux_channel_buffers: vec![vec![0.0; channel_buffer_len]; num_channels as usize],
        }
    }
}
