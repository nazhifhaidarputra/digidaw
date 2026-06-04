// src/lib.rs

use std::{path::PathBuf, sync::Arc};

use karbeat_core::audio::backend::AudioDeviceConfig;
use memmap2::MmapOptions;
use rtrb::RingBuffer;

pub(crate) use karbeat_core::{
    audio::backend::start_audio_stream,
    commands::AudioCommand,
    context::{ctx, INIT_LOGGER},
    core::project::track::audio_waveform::AudioWaveform,
};

pub mod api;
mod frb_generated;

pub use karbeat_core::context::{ctx as get_ctx, INIT_LOGGER as get_init};

pub fn init_logger() {
    // if release, use info, else use debug
    INIT_LOGGER.call_once(|| {
        use env_logger::Env;

        let default_level = if cfg!(debug_assertions) {
            "debug"
        } else {
            "info"
        };

        let _ = env_logger::Builder::from_env(Env::default().default_filter_or(default_level))
            .format_timestamp_millis()
            .target(env_logger::Target::Stdout)
            .try_init();
    });
}
