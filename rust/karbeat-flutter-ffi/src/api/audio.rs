use std::sync::Arc;
use std::time::Duration;

use crate::api::plugins::opaque::ZeroCopyHandle;
use crate::api::project::{AudioWaveformUiForAudioProperties, UiAudioHardwareConfig};
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
use karbeat_core::api::audio_api;
use karbeat_core::audio::event::{PluginTarget, TransportFeedback};
use karbeat_core::commands::{AudioFeedback, EffectTarget, MixerChannelTarget};
use karbeat_core::context::DawContext;
use karbeat_core::core::project::{AudioSourceId, GeneratorId, TrackId};
use karbeat_core::shared::id::{BusId, EffectId};

// ============================================================================
// Transport position feedback DTO
// ============================================================================

#[derive(Clone, Copy, Debug)]
#[frb(dart_metadata=("freezed"))]
pub struct UiTransportFeedback {
    pub samples: u32,
    pub ticks: u32,
    pub beat: usize,
    pub bar: usize,
    pub tempo: f32,
    pub sample_rate: u32,
    pub is_playing: bool,
    pub is_looping: bool,
    pub is_recording: bool,
    pub is_pattern_playing: bool,
    pub is_pattern_mode: bool,
    pub pattern_samples: u32,
    pub pattern_ticks: u32,
    pub pattern_beat: usize,
    pub pattern_bar: usize,
}

impl From<TransportFeedback> for UiTransportFeedback {
    fn from(f: TransportFeedback) -> Self {
        Self {
            samples: f.samples,
            ticks: f.ticks,
            beat: f.beat,
            bar: f.bar,
            tempo: f.tempo,
            sample_rate: f.sample_rate,
            is_playing: f.is_playing,
            is_looping: f.is_looping,
            is_recording: f.is_recording,
            is_pattern_playing: f.is_pattern_playing,
            is_pattern_mode: f.is_pattern_mode,
            pattern_samples: f.pattern_samples,
            pattern_ticks: f.pattern_ticks,
            pattern_beat: f.pattern_beat,
            pattern_bar: f.pattern_bar,
        }
    }
}

// ============================================================================
// Unified AudioFeedback DTO — replaces all per-domain polling streams
// ============================================================================

/// Unified DTO for all audio-thread → Flutter feedback messages.
///
/// Flutter receives these on a single `Stream<UiAudioFeedback>` opened by
/// `create_feedback_stream` and dispatches by variant on the Dart side.
/// This replaces the old per-domain polling approach
/// (`create_mixer_snapshot_stream`, `create_plugin_message_stream`, etc.).
#[derive(Clone)]
pub enum UiAudioFeedback {
    // ── Generator parameter feedback ──────────────────────────────────────
    /// A single generator parameter changed (e.g., driven by automation).
    GeneratorParameterChanged {
        generator_id: u32,
        param_id: u32,
        value: f32,
    },
    /// Full parameter snapshot for a generator (response to `query_generator_parameters`).
    GeneratorParameterSnapshot {
        generator_id: u32,
        /// (param_id, value) pairs
        parameters: Vec<(u32, f32)>,
    },

    // ── Effect parameter feedback ─────────────────────────────────────────
    /// A single effect parameter changed.
    EffectParameterChanged {
        /// `Some(id)` = track channel, `None` = master
        target_track_id: Option<u32>,
        target_bus_id: Option<u32>,
        effect_id: u32,
        param_id: u32,
        value: f32,
    },
    /// Full parameter snapshot for an effect (response to `query_effect_parameters`).
    EffectParameterSnapshot {
        target_track_id: Option<u32>,
        target_bus_id: Option<u32>,
        effect_id: u32,
        /// (param_id, value) pairs
        parameters: Vec<(u32, f32)>,
    },

    // ── Mixer channel feedback ────────────────────────────────────────────
    /// Full DSP state snapshot for a mixer channel (response to `query_mixer_channel`).
    MixerChannelSnapshot {
        /// `Some(id)` = track channel
        target_track_id: Option<u32>,
        /// `Some(id)` = bus channel
        target_bus_id: Option<u32>,
        /// `true` = master bus
        is_master: bool,
        volume: f32,
        pan: f32,
        mute: bool,
        solo: bool,
        inverted_phase: bool,
    },

    // ── Real-time plugin command response ─────────────────────────────────
    /// Response to `execute_realtime_plugin_command`. Correlate via `request_id`.
    PluginCommandResponse {
        request_id: u32,
        /// JSON-serialised response from the plugin's `execute_custom_command`.
        response_json: String,
    },

    // ── Plugin state snapshot ─────────────────────────────────────────────
    /// Raw state blob from a plugin instance (response to `QueryPluginState`).
    PluginStateSnapshot {
        /// `Some(id)` if the target is a generator
        generator_id: Option<u32>,
        /// Set if the target is a track effect
        track_effect_track_id: Option<u32>,
        track_effect_effect_id: Option<u32>,
        /// Set if the target is a bus effect
        bus_effect_bus_id: Option<u32>,
        bus_effect_effect_id: Option<u32>,
        /// Set if the target is a master-bus effect
        master_effect_id: Option<u32>,
        /// Raw serialised state bytes
        state: Vec<u8>,
        request_id: u32,
    },

    // ── Zero-copy buffer response ─────────────────────────────────────────
    /// Response to `query_live_plugin_zero_copy_buf`. Correlate via `request_id`.
    ZeroCopyBufferResponse {
        request_id: u32,
        /// `None` if the plugin did not recognise the buffer name.
        handle: Option<ZeroCopyHandle>,
    },
}

fn map_effect_target(target: &EffectTarget) -> (Option<u32>, Option<u32>) {
    match target {
        EffectTarget::Track(id) => (Some(id.to_u32()), None),
        EffectTarget::Bus(id) => (None, Some(id.to_u32())),
        EffectTarget::Master => (None, None),
    }
}

fn map_plugin_target(
    target: &PluginTarget,
) -> (
    Option<u32>,
    Option<u32>,
    Option<u32>,
    Option<u32>,
    Option<u32>,
    Option<u32>,
) {
    match target {
        PluginTarget::Generator(id) => (Some(id.to_u32()), None, None, None, None, None),
        PluginTarget::TrackEffect(track_id, effect_id) => (
            None,
            Some(track_id.to_u32()),
            Some(effect_id.to_u32()),
            None,
            None,
            None,
        ),
        PluginTarget::BusEffect(bus_id, effect_id) => (
            None,
            None,
            None,
            Some(bus_id.to_u32()),
            Some(effect_id.to_u32()),
            None,
        ),
        PluginTarget::MasterEffect(effect_id) => {
            (None, None, None, None, None, Some(effect_id.to_u32()))
        }
    }
}

impl From<AudioFeedback> for UiAudioFeedback {
    fn from(feedback: AudioFeedback) -> Self {
        match feedback {
            AudioFeedback::GeneratorParameterChanged(u) => Self::GeneratorParameterChanged {
                generator_id: u.generator_id.to_u32(),
                param_id: u.param_id,
                value: u.value,
            },
            AudioFeedback::GeneratorParameterSnapshot(s) => Self::GeneratorParameterSnapshot {
                generator_id: s.generator_id.to_u32(),
                parameters: s.parameters,
            },
            AudioFeedback::EffectParameterChanged(u) => {
                let (track_id, bus_id) = map_effect_target(&u.target);
                Self::EffectParameterChanged {
                    target_track_id: track_id,
                    target_bus_id: bus_id,
                    effect_id: u.effect_id.to_u32(),
                    param_id: u.param_id,
                    value: u.value,
                }
            }
            AudioFeedback::EffectParameterSnapshot(s) => {
                let (track_id, bus_id) = map_effect_target(&s.target);
                Self::EffectParameterSnapshot {
                    target_track_id: track_id,
                    target_bus_id: bus_id,
                    effect_id: s.effect_id.to_u32(),
                    parameters: s.parameters,
                }
            }
            AudioFeedback::MixerChannelSnapshot(s) => {
                let (target_track_id, target_bus_id, is_master) = match &s.target {
                    MixerChannelTarget::Track(id) => (Some(id.to_u32()), None, false),
                    MixerChannelTarget::Bus(id) => (None, Some(id.to_u32()), false),
                    MixerChannelTarget::Master => (None, None, true),
                };
                Self::MixerChannelSnapshot {
                    target_track_id,
                    target_bus_id,
                    is_master,
                    volume: s.volume,
                    pan: s.pan,
                    mute: s.mute,
                    solo: s.solo,
                    inverted_phase: s.inverted_phase,
                }
            }
            AudioFeedback::PluginCommandResponse {
                request_id,
                response,
            } => Self::PluginCommandResponse {
                request_id,
                response_json: response.to_string(),
            },
            AudioFeedback::PluginStateSnapshot {
                target,
                state,
                request_id,
            } => {
                let (
                    generator_id,
                    track_effect_track_id,
                    track_effect_effect_id,
                    bus_effect_bus_id,
                    bus_effect_effect_id,
                    master_effect_id,
                ) = map_plugin_target(&target);
                Self::PluginStateSnapshot {
                    generator_id,
                    track_effect_track_id,
                    track_effect_effect_id,
                    bus_effect_bus_id,
                    bus_effect_effect_id,
                    master_effect_id,
                    state,
                    request_id,
                }
            }
            AudioFeedback::ZeroCopyBufferResponse { request_id, buffer } => {
                Self::ZeroCopyBufferResponse {
                    request_id,
                    handle: buffer.map(ZeroCopyHandle::new),
                }
            }
        }
    }
}

// ============================================================================
// Streams
// ============================================================================

/// Opens a long-lived stream that forwards **all** `AudioFeedback` messages from
/// the audio thread to Flutter as `UiAudioFeedback` variants.
///
/// Flutter dispatches by variant on the Dart side — no per-domain polling
/// threads are needed. This stream replaces `create_mixer_snapshot_stream`,
/// `create_plugin_message_stream`, and `create_zero_copy_buffer_stream`.
///
/// Call this once after the audio backend is initialised. The stream runs
/// until Flutter closes the sink (returns an error), at which point the
/// consumer is returned to the context so the stream can be re-opened.
pub fn create_feedback_stream(
    ctx: &DawContext,
    sink: StreamSink<UiAudioFeedback>,
) -> Result<(), String> {
    let consumer_slot = Arc::clone(&ctx.feedback_consumer);

    let mut consumer = consumer_slot
        .lock()
        .take()
        .ok_or("AudioFeedback consumer is already running in another stream!")?;

    std::thread::spawn(move || {
        loop {
            while let Ok(feedback) = consumer.pop() {
                let ui_feedback = UiAudioFeedback::from(feedback);
                if sink.add(ui_feedback).is_err() {
                    log::info!("[Rust] AudioFeedback stream disconnected — stopping thread.");
                    // Return the consumer so the stream can be re-opened later
                    *consumer_slot.lock() = Some(consumer);
                    return;
                }
            }
            // ~60 fps poll interval — matches the transport position stream
            std::thread::sleep(Duration::from_millis(16));
        }
    });

    Ok(())
}

/// Opens a long-lived stream that forwards playback-position `TransportFeedback`
/// events from the audio thread to Flutter as `UiTransportFeedback`.
pub fn create_position_stream(
    sink: StreamSink<UiTransportFeedback>,
    ctx: &DawContext,
) -> Result<(), String> {
    let consumer_slot = Arc::clone(&ctx.position_consumer);

    // Take the consumer out of the Mutex so we own it
    let mut consumer = consumer_slot
        .lock()
        .take()
        .ok_or("Position consumer is already running in another stream!")?;

    // Spawn a thread to poll the ring buffer
    std::thread::spawn(move || {
        loop {
            while let Ok(feedback) = consumer.pop() {
                let ui_feedback = UiTransportFeedback::from(feedback);

                // Send to Flutter
                if sink.add(ui_feedback).is_err() {
                    log::info!("[Rust] PlaybackPosition Stream disconnected! Stopping thread.");
                    *consumer_slot.lock() = Some(consumer);
                    return;
                }
            }

            // Sleep to prevent high CPU usage on this polling thread
            // 16ms ~= 60fps
            std::thread::sleep(Duration::from_millis(16));
        }
    });
    Ok(())
}

// ============================================================================
// Audio source / preview functions
// ============================================================================

/// GETTER: Fetch details + Downsampled Buffer for UI
pub fn get_audio_properties(
    ctx: &DawContext,
    id: u32,
) -> Option<AudioWaveformUiForAudioProperties> {
    audio_api::get_audio_source(ctx, AudioSourceId::from(id), |waveform| {
        AudioWaveformUiForAudioProperties::try_from_with_context(ctx, waveform).ok()
    })?
}

/// ACTION: Play the sound via the Engine
pub fn play_source_preview(ctx: &mut DawContext, id: u32) {
    if let Err(e) = audio_api::play_source_preview(ctx, AudioSourceId::from(id)) {
        log::warn!("Preview failed: {}", e);
    } else {
        log::info!("Preview command sent for ID: {}", id);
    }
}

pub fn stop_all_previews(ctx: &mut DawContext) {
    audio_api::stop_all_previews(ctx);
    println!("Stop all preview sounds");
}

pub fn get_audio_config(ctx: &DawContext) -> Result<UiAudioHardwareConfig, String> {
    Ok(audio_api::get_audio_config(ctx, |config| {
        UiAudioHardwareConfig::from(config)
    }))
}

/// play preview sound when drawing note or pressing the piano tile on the UI
pub fn play_preview_note(
    ctx: &mut DawContext,
    track_id: u32,
    note_key: i32,
    velocity: i32,
    is_on: bool,
) -> Result<(), String> {
    if !(0..=127).contains(&note_key) {
        return Err("Note key must be between 0 and 127".to_string());
    }

    if !(0..=100).contains(&velocity) {
        return Err("Note velocity must be between 0 and 100".to_string());
    }

    audio_api::play_preview_note(
        ctx,
        TrackId::from(track_id),
        note_key as u8,
        velocity as u8,
        is_on,
    )
    .map_err(|e| e.to_string())
}

/// Play preview sound directly on a generator (without requiring a track).
/// Used in plugin editor screens to test synth sounds.
pub fn play_preview_note_generator(
    ctx: &mut DawContext,
    generator_id: u32,
    note_key: i32,
    velocity: i32,
    is_on: bool,
) -> Result<(), String> {
    if !(0..=127).contains(&note_key) {
        return Err("Note key must be between 0 and 127".to_string());
    }

    if !(0..=100).contains(&velocity) {
        return Err("Note velocity must be between 0 and 100".to_string());
    }

    audio_api::play_preview_note_generator(
        ctx,
        GeneratorId::from(generator_id),
        note_key as u8,
        velocity as u8,
        is_on,
    )
    .map_err(|e| e.to_string())
}

#[frb(sync)]
pub fn set_metronome_active(ctx: &mut DawContext, active: bool) {
    audio_api::set_metronome_active(ctx, active);
}
