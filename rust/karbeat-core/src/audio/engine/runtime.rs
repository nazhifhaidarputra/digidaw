use std::sync::mpsc;

use rtrb::{Consumer, Producer};

use crate::{
    audio::event::TransportFeedback,
    commands::{AudioCommand, AudioFeedback, TelemetryRegistration},
};

#[derive(Clone, Copy)]
pub(super) struct AudioEngineConfig {
    pub sample_rate: u32,
    pub num_channels: u16,
}

impl AudioEngineConfig {
    pub fn new(sample_rate: u32, num_channels: u16) -> Self {
        Self {
            sample_rate,
            num_channels,
        }
    }
}

pub(super) struct EngineIo {
    pub command_consumer: Consumer<AudioCommand>,
    pub position_producer: Producer<TransportFeedback>,
    pub feedback_producer: Producer<AudioFeedback>,
    pub telemetry_reg_sender: mpsc::SyncSender<TelemetryRegistration>,
}
