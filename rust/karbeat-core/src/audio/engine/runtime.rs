use std::{num::NonZero, sync::mpsc};

use rtrb::{Consumer, Producer};

use crate::{
    audio::{engine::runtime::consts::MAX_ENGINE_CHANNELS, event::TransportFeedback}, commands::{AudioCommand, AudioFeedback, TelemetryRegistration},
};

pub mod consts {
    pub const MAX_ENGINE_CHANNELS: u16 = 8;
}

#[derive(Clone, Copy)]
pub(super) struct AudioEngineConfig {
    pub sample_rate: u32,
    pub num_channels: u16,
}

impl AudioEngineConfig {
    pub fn new(sample_rate: u32, num_channels: u16) -> Self {
        Self {
            sample_rate,
            num_channels: num_channels.clamp(1, MAX_ENGINE_CHANNELS),
        }
    }
}

pub(super) struct EngineIo {
    pub command_consumer: Consumer<AudioCommand>,
    pub position_producer: Producer<TransportFeedback>,
    pub feedback_producer: Producer<AudioFeedback>,
    pub telemetry_reg_sender: mpsc::SyncSender<TelemetryRegistration>,
}
